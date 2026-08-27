/**
 * @description Test class for JT_LdvCheckpointPurgeBatch
 * @author Jaime Terrats
 **/
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.ApexDoc')
private class JT_LdvCheckpointPurgeBatch_Test {
  /**
   * @description Without a configured JT_LdvCheckpointRetentionDays__c, the batch must
   * fall back to a documented default rather than purging with an undefined window.
   */
  @IsTest
  static void testGetRetentionDaysFallsBackToDefaultWhenNotConfigured() {
    Test.startTest();
    Integer retentionDays = JT_LdvCheckpointPurgeBatch.getRetentionDays();
    Test.stopTest();

    Assert.areEqual(
      30,
      retentionDays,
      'getRetentionDays should fall back to the documented 30-day default'
    );
  }

  /**
   * @description The batch must delete only Completed/Failed checkpoints past the
   * retention window, leaving Pending/in-flight checkpoints untouched.
   */
  @IsTest
  static void testPurgeBatchDeletesOnlyEligibleCheckpoints() {
    JT_DynamicQuerySettings__c settings = JT_DynamicQuerySettings__c.getInstance();
    settings.JT_LdvCheckpointRetentionDays__c = -1;
    upsert settings;

    insert new List<JT_LDV_Checkpoint__c>{
      new JT_LDV_Checkpoint__c(
        JT_OperationId__c = '11111111-1111-1111-1111-111111111111',
        JT_ConfigDevName__c = 'Test_Record',
        JT_Status__c = 'Completed'
      ),
      new JT_LDV_Checkpoint__c(
        JT_OperationId__c = '22222222-2222-2222-2222-222222222222',
        JT_ConfigDevName__c = 'Test_Record',
        JT_Status__c = 'Pending'
      )
    };

    Test.startTest();
    Database.executeBatch(new JT_LdvCheckpointPurgeBatch(), 200);
    Test.stopTest();

    Integer remaining = [SELECT COUNT() FROM JT_LDV_Checkpoint__c];
    Assert.areEqual(
      1,
      remaining,
      'Only the non-eligible (Pending) checkpoint should remain after purge'
    );
  }
}
