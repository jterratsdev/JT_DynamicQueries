/**
 * @description Deletes Completed/Failed JT_LDV_Checkpoint__c rows older than the configured
 * retention window (JT_DynamicQuerySettings__c.JT_LdvCheckpointRetentionDays__c, default 30
 * days). Scheduling this job is a manual admin step - see CONTRIBUTING.md (ADR-001 §3/§7).
 * @author Jaime Terrats
 * @group Batch Apex
 */
public without sharing class JT_LdvCheckpointPurgeBatch implements Database.Batchable<SObject>, Schedulable {
  private static final Integer DEFAULT_RETENTION_DAYS = 30;

  /**
   * @description Schedulable entry point - kicks off the batch. Scheduled manually by an admin.
   * @param context SchedulableContext provided by the platform
   */
  public void execute(SchedulableContext context) {
    Database.executeBatch(new JT_LdvCheckpointPurgeBatch(), 200);
  }

  /**
   * @description Batchable start - scopes rows eligible for purge.
   * @param context BatchableContext provided by the platform
   * @return Database.QueryLocator Completed/Failed checkpoints older than the retention window
   */
  public Database.QueryLocator start(Database.BatchableContext context) {
    Datetime cutoff = System.now().addDays(-getRetentionDays());
    return Database.getQueryLocator(
      [
        SELECT Id
        FROM JT_LDV_Checkpoint__c
        WHERE JT_Status__c IN ('Completed', 'Failed')
        AND LastModifiedDate < :cutoff
      ]
    );
  }

  /**
   * @description Batchable execute - deletes the scoped checkpoint rows.
   * @param context BatchableContext provided by the platform
   * @param scope Checkpoint rows for this batch chunk
   */
  public void execute(Database.BatchableContext context, List<JT_LDV_Checkpoint__c> scope) {
    delete scope;
  }

  /**
   * @description Batchable finish - no post-processing required.
   * @param context BatchableContext provided by the platform
   */
  public void finish(Database.BatchableContext context) {
  }

  @TestVisible
  private static Integer getRetentionDays() {
    JT_DynamicQuerySettings__c settings = JT_DynamicQuerySettings__c.getInstance();
    return settings != null && settings.JT_LdvCheckpointRetentionDays__c != null
      ? Integer.valueOf(settings.JT_LdvCheckpointRetentionDays__c)
      : DEFAULT_RETENTION_DAYS;
  }
}
