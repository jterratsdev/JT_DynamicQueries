/**
 * @description Test class for JT_SetupWizardController
 * @author Jaime Terrats
 * @group Setup
 * @date 2025-12-14
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.ApexDoc')
private class JT_SetupWizardController_Test {
  /**
   * @description Test getOrgUrl returns org URL
   */
  @IsTest
  static void testGetOrgUrl() {
    Test.startTest();
    String orgUrl = JT_SetupWizardController.getOrgUrl();
    Test.stopTest();

    System.assertNotEquals(null, orgUrl, 'Org URL should not be null');
    System.assert(orgUrl.length() > 0, 'Org URL should not be empty');
  }

  /**
   * @description Test checkCompleteSetup returns setup status
   */
  @IsTest
  static void testCheckCompleteSetup() {
    Test.startTest();
    JT_SetupWizardController.CompleteSetupStatus status = JT_SetupWizardController.checkCompleteSetup();
    Test.stopTest();

    System.assertNotEquals(null, status, 'Status should not be null');
    System.assertNotEquals(null, status.orgUrl, 'Org URL should be populated');
    System.assertNotEquals(null, status.steps, 'Steps should not be null');
    System.assert(status.steps.size() > 0, 'Should have at least one step');

    // Verify Tooling API step
    JT_SetupWizardController.SetupStepStatus toolingStep = status.steps[0];
    System.assertNotEquals(
      null,
      toolingStep.stepName,
      'Step name should be populated'
    );
    System.assertEquals(
      true,
      toolingStep.isRequired,
      'Tooling API step should be required'
    );
    System.assertNotEquals(
      null,
      toolingStep.statusMessage,
      'Status message should be populated'
    );
  }

  /**
   * @description Test testToolingAPIConnection returns boolean
   * Note: This test may fail if Tooling API is not accessible in test context
   */
  @IsTest
  static void testTestToolingAPIConnection() {
    Test.startTest();
    Boolean connectionWorks = JT_SetupWizardController.testToolingAPIConnection();
    Test.stopTest();

    // Result depends on org configuration
    // Just verify it returns a boolean (doesn't throw exception)
    System.assertNotEquals(
      null,
      connectionWorks,
      'Should return boolean value'
    );
  }

  /**
   * @description Test SetupResult inner class structure
   */
  @IsTest
  static void testSetupResultStructure() {
    Test.startTest();
    JT_SetupWizardController.SetupResult result = new JT_SetupWizardController.SetupResult();
    result.success = true;
    result.message = 'Test message';
    result.details = 'Test details';
    result.orgUrl = 'https://test.salesforce.com';
    Test.stopTest();

    System.assertEquals(true, result.success, 'Success should be set');
    System.assertEquals(
      'Test message',
      result.message,
      'Message should be set'
    );
    System.assertEquals(
      'Test details',
      result.details,
      'Details should be set'
    );
    System.assertEquals(
      'https://test.salesforce.com',
      result.orgUrl,
      'Org URL should be set'
    );
  }

  /**
   * @description Test SetupStepStatus inner class structure
   */
  @IsTest
  static void testSetupStepStatusStructure() {
    Test.startTest();
    JT_SetupWizardController.SetupStepStatus step = new JT_SetupWizardController.SetupStepStatus();
    step.stepName = 'Test Step';
    step.isComplete = true;
    step.isRequired = true;
    step.statusMessage = 'Test status';
    step.setupUrl = 'https://test.salesforce.com';
    Test.stopTest();

    System.assertEquals('Test Step', step.stepName, 'Step name should be set');
    System.assertEquals(true, step.isComplete, 'Is complete should be set');
    System.assertEquals(true, step.isRequired, 'Is required should be set');
    System.assertEquals(
      'Test status',
      step.statusMessage,
      'Status message should be set'
    );
    System.assertEquals(
      'https://test.salesforce.com',
      step.setupUrl,
      'Setup URL should be set'
    );
  }

  /**
   * @description Test CompleteSetupStatus inner class structure
   */
  @IsTest
  static void testCompleteSetupStatusStructure() {
    Test.startTest();
    JT_SetupWizardController.CompleteSetupStatus status = new JT_SetupWizardController.CompleteSetupStatus();
    status.allStepsComplete = true;
    status.steps = new List<JT_SetupWizardController.SetupStepStatus>();
    status.orgUrl = 'https://test.salesforce.com';
    status.documentationUrl = '/lightning/n/JT_Project_Docs';
    Test.stopTest();

    System.assertEquals(
      true,
      status.allStepsComplete,
      'All steps complete should be set'
    );
    System.assertNotEquals(null, status.steps, 'Steps should be initialized');
    System.assertEquals(
      'https://test.salesforce.com',
      status.orgUrl,
      'Org URL should be set'
    );
    System.assertEquals(
      '/lightning/n/JT_Project_Docs',
      status.documentationUrl,
      'Documentation URL should be set'
    );
  }

  /**
   * @description Test testToolingAPIConnection with HTTP 200 success response
   */
  @IsTest
  static void testTestToolingAPIConnectionSuccess() {
    // Mock successful HTTP 200 response
    String successResponse = JSON.serialize(
      new Map<String, Object>{
        'size' => 1,
        'records' => new List<Object>{
          new Map<String, Object>{ 'Id' => '01p000000000000AAA' }
        }
      }
    );

    Test.setMock(
      HttpCalloutMock.class,
      new JT_ToolingAPIMock(200, successResponse)
    );

    Test.startTest();
    Boolean connectionWorks = JT_SetupWizardController.testToolingAPIConnection();
    Test.stopTest();

    System.assertEquals(
      true,
      connectionWorks,
      'Should return true for HTTP 200'
    );
  }

  /**
   * @description Test testToolingAPIConnection with HTTP error response (non-200)
   */
  @IsTest
  static void testTestToolingAPIConnectionHttpError() {
    // Mock HTTP error response (e.g., 401 Unauthorized)
    String errorResponse = JSON.serialize(
      new Map<String, Object>{
        'message' => 'Session expired or invalid',
        'errorCode' => 'INVALID_SESSION_ID'
      }
    );

    Test.setMock(
      HttpCalloutMock.class,
      new JT_ToolingAPIMock(401, errorResponse)
    );

    Test.startTest();
    Boolean connectionWorks = JT_SetupWizardController.testToolingAPIConnection();
    Test.stopTest();

    System.assertEquals(
      false,
      connectionWorks,
      'Should return false for HTTP error'
    );
  }

  /**
   * @description Test testToolingAPIConnection with HTTP 500 server error
   */
  @IsTest
  static void testTestToolingAPIConnectionServerError() {
    // Mock HTTP 500 server error
    Test.setMock(
      HttpCalloutMock.class,
      new JT_ToolingAPIMock(500, 'Internal Server Error')
    );

    Test.startTest();
    Boolean connectionWorks = JT_SetupWizardController.testToolingAPIConnection();
    Test.stopTest();

    System.assertEquals(
      false,
      connectionWorks,
      'Should return false for server error'
    );
  }

  /**
   * @description Test testToolingAPIConnection with CalloutException
   */
  @IsTest
  static void testTestToolingAPIConnectionCalloutException() {
    // Mock callout exception (simulates network failure)
    Test.setMock(HttpCalloutMock.class, new JT_ToolingAPIMock());

    Test.startTest();
    Boolean connectionWorks = JT_SetupWizardController.testToolingAPIConnection();
    Test.stopTest();

    System.assertEquals(
      false,
      connectionWorks,
      'Should return false on callout exception'
    );
  }

  /**
   * @description Test checkCompleteSetup when Tooling API connection fails
   */
  @IsTest
  static void testCheckCompleteSetupConnectionFailed() {
    // Mock HTTP error to simulate connection failure
    Test.setMock(
      HttpCalloutMock.class,
      new JT_ToolingAPIMock(401, 'Unauthorized')
    );

    Test.startTest();
    JT_SetupWizardController.CompleteSetupStatus status = JT_SetupWizardController.checkCompleteSetup();
    Test.stopTest();

    System.assertNotEquals(null, status, 'Status should not be null');
    System.assertNotEquals(null, status.steps, 'Steps should not be null');
    System.assertEquals(2, status.steps.size(), 'Should have two steps');

    JT_SetupWizardController.SetupStepStatus toolingStep = status.steps[0];
    System.assertEquals(
      false,
      toolingStep.isComplete,
      'Step should be incomplete'
    );
    System.assertEquals(
      false,
      status.allStepsComplete,
      'All steps should not be complete'
    );
    System.assertNotEquals(
      null,
      toolingStep.statusMessage,
      'Status message should be populated'
    );
  }

  /**
   * @description The optional LDV checkpoint purge step must never block allStepsComplete,
   * even when no CronTrigger is scheduled (ADR-001 §3/§7 - manual admin step).
   */
  @IsTest
  static void testCheckCompleteSetupLdvPurgeStepIsOptionalAndDoesNotBlock() {
    Test.setMock(HttpCalloutMock.class, new JT_ToolingAPIMock(200, 'OK'));

    Test.startTest();
    JT_SetupWizardController.CompleteSetupStatus status = JT_SetupWizardController.checkCompleteSetup();
    Test.stopTest();

    JT_SetupWizardController.SetupStepStatus ldvPurgeStep = status.steps[1];
    System.assertEquals(
      false,
      ldvPurgeStep.isRequired,
      'LDV checkpoint purge step must be optional so an unscheduled job never blocks setup'
    );
  }

  /**
   * @description With no CronTrigger scheduled, isLdvCheckpointPurgeScheduled must return false.
   */
  @IsTest
  static void testIsLdvCheckpointPurgeScheduledFalseWhenNotScheduled() {
    Test.startTest();
    Boolean isScheduled = JT_SetupWizardController.isLdvCheckpointPurgeScheduled();
    Test.stopTest();

    System.assertEquals(
      false,
      isScheduled,
      'isLdvCheckpointPurgeScheduled should be false when no matching CronTrigger exists'
    );
  }
}
