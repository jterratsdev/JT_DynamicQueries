/**
 * @description Bounded retry-with-backoff for JT_LdvCursorQueueable.
 * On transient failure, re-enqueues the same chunk position with a bounded delay. On fatal
 * failure or retry exhaustion, marks the checkpoint Failed and stops the chain (fail closed -
 * never silently drops an operation without a terminal status).
 * @author Jaime Terrats
 * @group LDV
 */
public without sharing class JT_LdvCursorFinalizer implements Finalizer {
  private final Id checkpointId;

  public JT_LdvCursorFinalizer(Id checkpointId) {
    this.checkpointId = checkpointId;
  }

  public void execute(FinalizerContext context) {
    if (context.getResult() == ParentJobResult.SUCCESS) {
      return;
    }

    String lastError = context.getException() != null
      ? context.getException().getTypeName() +
        ': ' +
        context.getException().getMessage()
      : 'Unhandled exception - no exception detail available';
    handleFailure(checkpointId, lastError);
  }

  /**
   * @description Decides retry-vs-fail-closed and applies it. Split out from execute() so the
   * decision logic is directly unit-testable without needing a real async job failure - the
   * platform provides no way to construct a FinalizerContext in test code.
   * @param checkpointId The failed operation's checkpoint
   * @param lastError Error type/message to persist (never bind values)
   */
  @TestVisible
  private static void handleFailure(Id checkpointId, String lastError) {
    JT_LDV_Checkpoint__c checkpoint = [
      SELECT JT_RetryCount__c, JT_MaxRetries__c
      FROM JT_LDV_Checkpoint__c
      WHERE Id = :checkpointId
      WITH SYSTEM_MODE
    ];

    Integer retryCount = (Integer) checkpoint.JT_RetryCount__c + 1;
    Integer maxRetries = (Integer) checkpoint.JT_MaxRetries__c;

    checkpoint.JT_RetryCount__c = retryCount;
    checkpoint.JT_LastError__c = lastError;

    if (retryCount > maxRetries) {
      checkpoint.JT_Status__c = 'Failed';
      Database.update(checkpoint, AccessLevel.SYSTEM_MODE);
      return;
    }

    checkpoint.JT_Status__c = 'RetryPending';
    Database.update(checkpoint, AccessLevel.SYSTEM_MODE);

    Integer delayMinutes = Math.min(10, retryCount * 2);
    System.enqueueJob(new JT_LdvCursorQueueable(checkpointId), delayMinutes);
  }
}
