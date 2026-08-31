/**
 * @description Controller for Setup Wizard LWC - Verifies Tooling API accessibility
 * @author Jaime Terrats
 * @group Setup
 */
public without sharing class JT_SetupWizardController {
  /**
   * @description Result wrapper for setup operations
   */
  public class SetupResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public String details;
    @AuraEnabled
    public String orgUrl;
  }

  /**
   * @description Step status for multi-step setup wizard
   */
  public class SetupStepStatus {
    @AuraEnabled
    public String stepName;
    @AuraEnabled
    public Boolean isComplete;
    @AuraEnabled
    public Boolean isRequired;
    @AuraEnabled
    public String statusMessage;
    @AuraEnabled
    public String setupUrl;
  }

  /**
   * @description Complete setup status with all steps
   */
  public class CompleteSetupStatus {
    @AuraEnabled
    public Boolean allStepsComplete;
    @AuraEnabled
    public List<SetupStepStatus> steps;
    @AuraEnabled
    public String orgUrl;
    @AuraEnabled
    public String documentationUrl;
  }

  /**
   * @description Checks Tooling API setup status
   * Uses UserInfo.getSessionId() directly for same-org Tooling API calls
   * @return CompleteSetupStatus Status of setup
   */
  @AuraEnabled
  public static CompleteSetupStatus checkCompleteSetup() {
    final CompleteSetupStatus status = new CompleteSetupStatus();
    status.orgUrl = JT_ToolingApiUtil.getOrgDomainUrl();
    status.documentationUrl = '/lightning/n/JT_Project_Docs';
    status.steps = new List<SetupStepStatus>();

    // Step 1: Test Tooling API Connection
    final SetupStepStatus testStep = new SetupStepStatus();
    testStep.stepName = Label.JT_SetupWizardController_stepNameToolingApi;
    testStep.isRequired = true;
    testStep.setupUrl = null;
    final Boolean connectionWorks = testToolingAPIConnection();
    testStep.isComplete = connectionWorks;
    testStep.statusMessage = connectionWorks
      ? Label.JT_SetupWizardController_toolingApiAccessible
      : Label.JT_SetupWizardController_toolingApiConnectionFailed;
    status.steps.add(testStep);

    // Step 2: LDV Checkpoint Purge job scheduled (optional - manual admin step)
    final SetupStepStatus ldvPurgeStep = new SetupStepStatus();
    ldvPurgeStep.stepName = Label.JT_SetupWizardController_stepNameLdvPurge;
    ldvPurgeStep.isRequired = false;
    ldvPurgeStep.setupUrl = null;
    final Boolean purgeScheduled = isLdvCheckpointPurgeScheduled();
    ldvPurgeStep.isComplete = purgeScheduled;
    ldvPurgeStep.statusMessage = purgeScheduled
      ? Label.JT_SetupWizardController_ldvPurgeScheduled
      : Label.JT_SetupWizardController_ldvPurgeNotScheduled;
    status.steps.add(ldvPurgeStep);

    // Calculate overall status from required steps only - optional steps never block it
    Boolean allRequiredComplete = true;
    for (SetupStepStatus step : status.steps) {
      if (step.isRequired && !step.isComplete) {
        allRequiredComplete = false;
      }
    }
    status.allStepsComplete = allRequiredComplete;

    return status;
  }

  /**
   * @description Checks whether an admin has scheduled JT_LdvCheckpointPurgeBatch
   * (CONTRIBUTING.md "Scheduled Jobs"). Purely observational - never schedules it.
   * @return Boolean True if a matching CronTrigger exists
   */
  @AuraEnabled
  public static Boolean isLdvCheckpointPurgeScheduled() {
    return ![
        SELECT Id
        FROM CronTrigger
        WHERE
          CronJobDetail.JobType = '7'
          AND CronJobDetail.Name = 'JT LDV Checkpoint Purge'
        WITH SYSTEM_MODE
        LIMIT 1
      ]
      .isEmpty();
  }

  /**
   * @description Tests Tooling API connection using API-enabled session ID from VFP
   * This method uses Visualforce page to get API-enabled session ID
   * because UserInfo.getSessionId() doesn't work from LWC context
   * @return Boolean True if connection works
   */
  @AuraEnabled
  @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
  // Manual Authorization header is necessary here to bypass Named Credential proxy for same-org calls
  public static Boolean testToolingAPIConnection() {
    try {
      final String query = JT_SystemSelector.getToolingApiTestQuery();
      final String orgUrl = JT_ToolingApiUtil.getOrgDomainUrl();

      System.debug(LoggingLevel.INFO, 'Testing Tooling API connection');
      System.debug(LoggingLevel.INFO, 'Org URL: ' + orgUrl);

      final HttpRequest request = JT_ToolingApiUtil.createToolingApiQueryRequest(
        query,
        10000
      );

      final Http httpClient = new Http();
      final HttpResponse response = httpClient.send(request);

      System.debug(
        LoggingLevel.INFO,
        'Response Status Code: ' + response.getStatusCode()
      );
      System.debug(
        LoggingLevel.INFO,
        'Response Status: ' + response.getStatus()
      );

      if (response.getStatusCode() != 200) {
        System.debug(LoggingLevel.WARN, 'Response Body: ' + response.getBody());
      }

      return response.getStatusCode() == 200;
    } catch (System.CalloutException e) {
      System.debug(
        LoggingLevel.ERROR,
        'Tooling API callout exception: ' + e.getMessage()
      );
      System.debug(
        LoggingLevel.ERROR,
        'Stack trace: ' + e.getStackTraceString()
      );
      return false;
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'Tooling API test failed: ' + e.getMessage()
      );
      System.debug(LoggingLevel.ERROR, 'Exception type: ' + e.getTypeName());
      System.debug(
        LoggingLevel.ERROR,
        'Stack trace: ' + e.getStackTraceString()
      );
      return false;
    }
  }

  /**
   * @description Gets org URL for manual setup
   * @return String Org instance URL
   */
  @AuraEnabled
  public static String getOrgUrl() {
    return JT_ToolingApiUtil.getOrgDomainUrl();
  }
}
