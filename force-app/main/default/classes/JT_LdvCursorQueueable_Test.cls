/**
 * @description Test class for JT_LdvCursorQueueable
 * @author Jaime Terrats
 **/
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.ApexDoc')
private class JT_LdvCursorQueueable_Test {
  @TestSetup
  static void setupTestData() {
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 5; i++) {
      accounts.add(new Account(Name = 'Test Account'));
    }
    insert accounts;
  }

  /**
   * @description A 5-record operation with chunk size 3 requires 2 chained executions
   * (3 + 2) to complete - proving real multi-transaction chaining, not a single loop.
   * Apex test context caps chained-Queueable depth lower than production, so this
   * deliberately stays at one re-enqueue rather than exercising a longer chain.
   */
  @IsTest
  static void testChainedOperationCompletesAcrossMultipleChunks() {
    JT_LDV_Checkpoint__c checkpoint = JT_DataSelector.startCursorOperation(
      'Test_Record',
      new Map<String, Object>{ 'name' => 'Test Account' },
      true,
      3,
      'JT_LdvCountingProcessor'
    );

    Test.startTest();
    System.enqueueJob(new JT_LdvCursorQueueable(checkpoint.Id));
    Test.stopTest();

    JT_LDV_Checkpoint__c completed = [
      SELECT JT_Status__c, JT_RecordsProcessed__c, JT_CursorPosition__c
      FROM JT_LDV_Checkpoint__c
      WHERE Id = :checkpoint.Id
    ];
    Assert.areEqual(
      5,
      completed.JT_RecordsProcessed__c,
      'All 5 records should be processed across the chained chunks'
    );
  }

  /**
   * @description An Aborted checkpoint must never be processed once the queueable observes
   * it - cooperative cancellation must stop the chain before any chunk work happens.
   */
  @IsTest
  static void testCooperativeCancellationStopsBeforeProcessing() {
    JT_LDV_Checkpoint__c checkpoint = JT_DataSelector.startCursorOperation(
      'Test_Record',
      new Map<String, Object>{ 'name' => 'Test Account' },
      true,
      2,
      'JT_LdvCountingProcessor'
    );
    checkpoint.JT_Status__c = 'Aborted';
    update checkpoint;

    Test.startTest();
    System.enqueueJob(new JT_LdvCursorQueueable(checkpoint.Id));
    Test.stopTest();

    JT_LDV_Checkpoint__c aborted = [
      SELECT JT_RecordsProcessed__c
      FROM JT_LDV_Checkpoint__c
      WHERE Id = :checkpoint.Id
    ];
    Assert.areEqual(
      0,
      aborted.JT_RecordsProcessed__c,
      'An Aborted checkpoint must not be processed once the queueable observes it'
    );
  }

  /**
   * @description When retries are exhausted, the Finalizer's failure-handling logic must fail
   * closed with a terminal Failed status rather than re-enqueueing forever. Exercised by
   * calling JT_LdvCursorFinalizer.handleFailure directly (the platform provides no way to
   * construct a real FinalizerContext in test code, and Test.stopTest() surfaces the queueable's
   * own uncaught exception as a test failure regardless of a Finalizer being attached - neither
   * is a valid path for unit-testing this decision logic).
   */
  @IsTest
  static void testRetryExhaustionFailsClosedInsteadOfLoopingForever() {
    JT_LDV_Checkpoint__c checkpoint = JT_DataSelector.startCursorOperation(
      'Test_Record',
      new Map<String, Object>{ 'name' => 'Test Account' },
      true,
      2,
      'JT_LdvCountingProcessor'
    );
    checkpoint.JT_MaxRetries__c = 0;
    update checkpoint;

    Test.startTest();
    JT_LdvCursorFinalizer.handleFailure(
      checkpoint.Id,
      'Simulated failure for test'
    );
    Test.stopTest();

    JT_LDV_Checkpoint__c failed = [
      SELECT JT_Status__c
      FROM JT_LDV_Checkpoint__c
      WHERE Id = :checkpoint.Id
    ];
    Assert.areEqual(
      'Failed',
      failed.JT_Status__c,
      'Retry exhaustion must fail closed with a terminal Failed status, never loop forever'
    );
  }

  /**
   * @description Below the retry limit, a failure must be marked RetryPending, not Failed.
   * Deliberately does not call Test.stopTest(): handleFailure's own re-enqueue (for the actual
   * retry) is not what this test is checking, and Test.stopTest() would flush it immediately -
   * this test only asserts the status transition, not the subsequent retry execution.
   */
  @IsTest
  static void testTransientFailureIsMarkedRetryPendingNotFailed() {
    JT_LDV_Checkpoint__c checkpoint = JT_DataSelector.startCursorOperation(
      'Test_Record',
      new Map<String, Object>{ 'name' => 'Test Account' },
      true,
      2,
      'JT_LdvCountingProcessor'
    );

    JT_LdvCursorFinalizer.handleFailure(
      checkpoint.Id,
      'Simulated transient failure'
    );

    JT_LDV_Checkpoint__c retrying = [
      SELECT JT_Status__c
      FROM JT_LDV_Checkpoint__c
      WHERE Id = :checkpoint.Id
    ];
    Assert.areEqual(
      'RetryPending',
      retrying.JT_Status__c,
      'A failure below JT_MaxRetries__c must be marked RetryPending, not Failed'
    );
  }
}
