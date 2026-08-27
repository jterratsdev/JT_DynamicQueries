/**
 * @description Chained Queueable that fetches one bounded chunk from a real Database.Cursor
 * per transaction, driven entirely by a durable JT_LDV_Checkpoint__c row.
 * Each execution is independently bounded: it re-opens Database.getCursorWithBinds using the
 * checkpoint's persisted config/bindings, fetches exactly one chunk at the checkpoint's
 * position, persists progress, then re-enqueues itself for the next chunk. No CursorProcessor
 * instance or in-memory result set is carried across transactions.
 * @author Jaime Terrats
 * @group LDV
 */
public without sharing class JT_LdvCursorQueueable implements Queueable {
  @TestVisible
  private Id checkpointId;

  public JT_LdvCursorQueueable(Id checkpointId) {
    this.checkpointId = checkpointId;
  }

  public void execute(QueueableContext context) {
    JT_LDV_Checkpoint__c checkpoint = [
      SELECT
        JT_ConfigDevName__c,
        JT_BindingsJson__c,
        JT_ChunkSize__c,
        JT_CursorPosition__c,
        JT_RecordsProcessed__c,
        JT_TotalRecordCount__c,
        JT_Status__c,
        JT_ProcessorClass__c
      FROM JT_LDV_Checkpoint__c
      WHERE Id = :checkpointId
      WITH SYSTEM_MODE
    ];

    if (
      checkpoint.JT_Status__c == 'Aborted' ||
      checkpoint.JT_Status__c == 'Completed'
    ) {
      return;
    }

    System.attachFinalizer(new JT_LdvCursorFinalizer(checkpointId));

    Map<String, Object> persistedState = (Map<String, Object>) JSON.deserializeUntyped(
      checkpoint.JT_BindingsJson__c
    );
    Map<String, Object> bindings = (Map<String, Object>) persistedState.get(
      'bindings'
    );
    Boolean enforceSecurity = (Boolean) persistedState.get('enforceSecurity');
    AccessLevel accessMode = enforceSecurity == true
      ? AccessLevel.USER_MODE
      : AccessLevel.SYSTEM_MODE;

    String baseQuery = JT_DataSelector.getBaseQuery(
      checkpoint.JT_ConfigDevName__c
    );

    Integer position = (Integer) checkpoint.JT_CursorPosition__c;
    Integer chunkSize = (Integer) checkpoint.JT_ChunkSize__c;
    Integer totalSize = (Integer) checkpoint.JT_TotalRecordCount__c;
    Integer fetchSize = Math.min(chunkSize, totalSize - position);

    List<SObject> batch = new List<SObject>();
    if (fetchSize > 0) {
      Database.Cursor cursor = Database.getCursorWithBinds(
        baseQuery,
        bindings,
        accessMode
      );
      batch = cursor.fetch(position, fetchSize);
    }

    JT_DataSelector.CursorProcessor processor = (JT_DataSelector.CursorProcessor) Type.forName(
        checkpoint.JT_ProcessorClass__c
      )
      .newInstance();
    if (!batch.isEmpty()) {
      processor.processBatch(batch);
    }

    Integer newPosition = position + batch.size();
    Boolean isDone = newPosition >= totalSize || batch.isEmpty();

    checkpoint.JT_CursorPosition__c = newPosition;
    checkpoint.JT_RecordsProcessed__c =
      (Integer) checkpoint.JT_RecordsProcessed__c + batch.size();
    checkpoint.JT_LastCheckpointAt__c = System.now();
    checkpoint.JT_RetryCount__c = 0;
    checkpoint.JT_Status__c = isDone ? 'Completed' : 'InProgress';
    if (isDone) {
      checkpoint.JT_CompletedAt__c = System.now();
    }
    Database.update(checkpoint, AccessLevel.SYSTEM_MODE);

    if (!isDone) {
      System.enqueueJob(new JT_LdvCursorQueueable(checkpointId));
    }
  }
}
