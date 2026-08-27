import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import clearPlatformCache from "@salesforce/apex/JT_QueryViewerController.clearPlatformCache";
import {
  formatLabel,
  getFieldType,
  showSuccessToast,
  showErrorToast,
  showInfoToast,
  showWarningToast,
  extractErrorMessage,
  getLabels,
  validateConfigExists,
  validateRequiredFields,
  validateQuerySyntax,
  sanitizeConfigData,
  validateEditMode,
  pollUntilComplete,
  validateConfigSelected,
  validateAndFindConfig
} from "c/jtUtils";
// Import Custom Labels from Salesforce Translation Workbench
import apexClassLabel from "@salesforce/label/c.JT_jtQueryViewer_apexClass";
import autoDetectedFromQueryLabel from "@salesforce/label/c.JT_jtQueryViewer_autoDetectedFromQuery";
import baseQueryLabel from "@salesforce/label/c.JT_jtQueryViewer_baseQuery";
import bindingsLabel from "@salesforce/label/c.JT_jtQueryViewer_bindings";
import cacheClearedLabel from "@salesforce/label/c.JT_jtQueryViewer_cacheCleared";
import cacheClearedDetailLabel from "@salesforce/label/c.JT_jtQueryViewer_cacheClearedDetail";
import cancelLabel from "@salesforce/label/c.JT_jtQueryViewer_cancel";
import chooseConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_chooseConfiguration";
import clearLabel from "@salesforce/label/c.JT_jtQueryViewer_clear";
import clearCacheLabel from "@salesforce/label/c.JT_jtQueryViewer_clearCache";
import clearCacheButtonLabel from "@salesforce/label/c.JT_jtQueryViewer_clearCacheButton";
import clearCacheDescriptionLabel from "@salesforce/label/c.JT_jtQueryViewer_clearCacheDescription";
import clearCacheTitleLabel from "@salesforce/label/c.JT_jtQueryViewer_clearCacheTitle";
import clearCacheWarningLabel from "@salesforce/label/c.JT_jtQueryViewer_clearCacheWarning";
import clearConfigurationsHelpLabel from "@salesforce/label/c.JT_jtQueryViewer_clearConfigurationsHelp";
import clearConfigurationsLabelLabel from "@salesforce/label/c.JT_jtQueryViewer_clearConfigurationsLabel";
import clearRecentHelpLabel from "@salesforce/label/c.JT_jtQueryViewer_clearRecentHelp";
import clearRecentLabelLabel from "@salesforce/label/c.JT_jtQueryViewer_clearRecentLabel";
import clearResultsHelpLabel from "@salesforce/label/c.JT_jtQueryViewer_clearResultsHelp";
import clearResultsLabelLabel from "@salesforce/label/c.JT_jtQueryViewer_clearResultsLabel";
import clearSelectionLabel from "@salesforce/label/c.JT_jtQueryViewer_clearSelection";
import clearUsersHelpLabel from "@salesforce/label/c.JT_jtQueryViewer_clearUsersHelp";
import clearUsersLabelLabel from "@salesforce/label/c.JT_jtQueryViewer_clearUsersLabel";
import codeLabel from "@salesforce/label/c.JT_jtQueryViewer_code";
import createConfigTooltipLabel from "@salesforce/label/c.JT_jtQueryViewer_createConfigTooltip";
import createNewConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_createNewConfiguration";
import developerNameLabel from "@salesforce/label/c.JT_jtQueryViewer_developerName";
import developerNameCannotEndWithUnderscoreLabel from "@salesforce/label/c.JT_jtQueryViewer_developerNameCannotEndWithUnderscore";
import developerNameInvalidCharsLabel from "@salesforce/label/c.JT_jtQueryViewer_developerNameInvalidChars";
import developerNameMustStartWithLetterLabel from "@salesforce/label/c.JT_jtQueryViewer_developerNameMustStartWithLetter";
import developerNameNoConsecutiveUnderscoresLabel from "@salesforce/label/c.JT_jtQueryViewer_developerNameNoConsecutiveUnderscores";
import developerNameRequiredLabel from "@salesforce/label/c.JT_jtQueryViewer_developerNameRequired";
import developerNameTooLongLabel from "@salesforce/label/c.JT_jtQueryViewer_developerNameTooLong";
import editConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_editConfiguration";
import executeQueryLabel from "@salesforce/label/c.JT_jtQueryViewer_executeQuery";
import executeSystemRunAsLabel from "@salesforce/label/c.JT_jtQueryViewer_executeSystemRunAs";
import executingTestLabel from "@salesforce/label/c.JT_jtQueryViewer_executingTest";
import findingUsageLabel from "@salesforce/label/c.JT_jtQueryViewer_findingUsage";
import foundReferencesLabel from "@salesforce/label/c.JT_jtQueryViewer_foundReferences";
import invalidQueryLabel from "@salesforce/label/c.JT_jtQueryViewer_invalidQuery";
import labelLabel from "@salesforce/label/c.JT_jtQueryViewer_label";
import labelRequiredLabel from "@salesforce/label/c.JT_jtQueryViewer_labelRequired";
import labelTooLongLabel from "@salesforce/label/c.JT_jtQueryViewer_labelTooLong";
import lineLabel from "@salesforce/label/c.JT_jtQueryViewer_line";
import lineNumberLabel from "@salesforce/label/c.JT_jtQueryViewer_lineNumber";
import loadingUsersLabel from "@salesforce/label/c.JT_jtQueryViewer_loadingUsers";
import nameLabel from "@salesforce/label/c.JT_jtQueryViewer_name";
import nextLabel from "@salesforce/label/c.JT_jtQueryViewer_next";
import noParametersRequiredLabel from "@salesforce/label/c.JT_jtQueryViewer_noParametersRequired";
import noReferencesFoundLabel from "@salesforce/label/c.JT_jtQueryViewer_noReferencesFound";
import noResultsLabel from "@salesforce/label/c.JT_jtQueryViewer_noResults";
import noUsageFoundLabel from "@salesforce/label/c.JT_jtQueryViewer_noUsageFound";
import noUsageMessageLabel from "@salesforce/label/c.JT_jtQueryViewer_noUsageMessage";
import objectLabel from "@salesforce/label/c.JT_jtQueryViewer_object";
import objectNameLabel from "@salesforce/label/c.JT_jtQueryViewer_objectName";
import objectNameReadOnlyLabel from "@salesforce/label/c.JT_jtQueryViewer_objectNameReadOnly";
import ofLabel from "@salesforce/label/c.JT_jtQueryViewer_of";
import pageLabel from "@salesforce/label/c.JT_jtQueryViewer_page";
import predefinedBindingsLabel from "@salesforce/label/c.JT_jtQueryViewer_predefinedBindings";
import predefinedBindingsDescLabel from "@salesforce/label/c.JT_jtQueryViewer_predefinedBindingsDesc";
import previousLabel from "@salesforce/label/c.JT_jtQueryViewer_previous";
import queryParametersLabel from "@salesforce/label/c.JT_jtQueryViewer_queryParameters";
import queryPreviewLabel from "@salesforce/label/c.JT_jtQueryViewer_queryPreview";
import queryPreviewTitleLabel from "@salesforce/label/c.JT_jtQueryViewer_queryPreviewTitle";
import recordLabel from "@salesforce/label/c.JT_jtQueryViewer_record";
import recordsLabel from "@salesforce/label/c.JT_jtQueryViewer_records";
import resultsLabel from "@salesforce/label/c.JT_jtQueryViewer_results";
import runAsNoteLabel from "@salesforce/label/c.JT_jtQueryViewer_runAsNote";
import runAsUserLabel from "@salesforce/label/c.JT_jtQueryViewer_runAsUser";
import sandboxOnlyWarningLabel from "@salesforce/label/c.JT_jtQueryViewer_sandboxOnlyWarning";
import saveLabel from "@salesforce/label/c.JT_jtQueryViewer_save";
import searchConfigsPlaceholderLabel from "@salesforce/label/c.JT_jtQueryViewer_searchConfigsPlaceholder";
import searchUsersPlaceholderLabel from "@salesforce/label/c.JT_jtQueryViewer_searchUsersPlaceholder";
import searchingFlowsLabel from "@salesforce/label/c.JT_jtQueryViewer_searchingFlows";
import searchingUsageMessageLabel from "@salesforce/label/c.JT_jtQueryViewer_searchingUsageMessage";
import selectAllLabel from "@salesforce/label/c.JT_jtQueryViewer_selectAll";
import selectConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_selectConfiguration";
import selectOptionLabel from "@salesforce/label/c.JT_jtQueryViewer_selectOption";
import selectUserLabel from "@salesforce/label/c.JT_jtQueryViewer_selectUser";
import showingLabel from "@salesforce/label/c.JT_jtQueryViewer_showing";
import toolingAPINoteLabel from "@salesforce/label/c.JT_jtQueryViewer_toolingAPINote";
import setupRequiredLabel from "@salesforce/label/c.JT_jtQueryViewer_setupRequired";
import namedCredentialSetupLabel from "@salesforce/label/c.JT_jtQueryViewer_namedCredentialSetup";
import toolingApiSetupLinkLabel from "@salesforce/label/c.JT_jtQueryViewer_toolingApiSetupLink";
import typeLabel from "@salesforce/label/c.JT_jtQueryViewer_type";
import typeToFilterLabel from "@salesforce/label/c.JT_jtQueryViewer_typeToFilter";
import updateConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_updateConfiguration";
import usageModalSubtitleLabel from "@salesforce/label/c.JT_jtQueryViewer_usageModalSubtitle";
import usageModalTitleLabel from "@salesforce/label/c.JT_jtQueryViewer_usageModalTitle";
import validQueryLabel from "@salesforce/label/c.JT_jtQueryViewer_validQuery";
import validSOQLSyntaxLabel from "@salesforce/label/c.JT_jtQueryViewer_validSOQLSyntax";
import whereIsThisUsedLabel from "@salesforce/label/c.JT_jtQueryViewer_whereIsThisUsed";
import whereIsThisUsedTooltipLabel from "@salesforce/label/c.JT_jtQueryViewer_whereIsThisUsedTooltip";
import skipToMainContentLabel from "@salesforce/label/c.JT_jtQueryViewer_skipToMainContent";
import loadingApplicationLabel from "@salesforce/label/c.JT_jtQueryViewer_loadingApplication";
import loadingDynamicQueryViewerLabel from "@salesforce/label/c.JT_jtQueryViewer_loadingDynamicQueryViewer";
import searchingForUsageLabel from "@salesforce/label/c.JT_jtQueryViewer_searchingForUsage";
import searchingLabel from "@salesforce/label/c.JT_jtQueryViewer_searching";
import dynamicQueryViewerLabel from "@salesforce/label/c.JT_jtQueryViewer_dynamicQueryViewer";
import clearCacheAndRefreshLabel from "@salesforce/label/c.JT_jtQueryViewer_clearCacheAndRefresh";
import openCacheManagementModalLabel from "@salesforce/label/c.JT_jtQueryViewer_openCacheManagementModal";
import createConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_createConfiguration";
import createNewQueryConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_createNewQueryConfiguration";
import createNewQueryConfigurationAriaLabel from "@salesforce/label/c.JT_jtQueryViewer_createNewQueryConfigurationAria";
import editConfigurationNewLabel from "@salesforce/label/c.JT_jtQueryViewer_editConfiguration";
import editSelectedConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_editSelectedConfiguration";
import editSelectedQueryConfigurationAriaLabel from "@salesforce/label/c.JT_jtQueryViewer_editSelectedQueryConfigurationAria";
import deleteConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_deleteConfiguration";
import deleteSelectedConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_deleteSelectedConfiguration";
import deleteSelectedQueryConfigurationAriaLabel from "@salesforce/label/c.JT_jtQueryViewer_deleteSelectedQueryConfigurationAria";
import productionLabel from "@salesforce/label/c.JT_jtQueryViewer_production";
import readOnlyModeInProductionLabel from "@salesforce/label/c.JT_jtQueryViewer_readOnlyModeInProduction";
import queryViewerMainContentLabel from "@salesforce/label/c.JT_jtQueryViewer_queryViewerMainContent";
import warningLabel from "@salesforce/label/c.JT_jtQueryViewer_warning";
import productionEnvironmentDetectedLabel from "@salesforce/label/c.JT_jtQueryViewer_productionEnvironmentDetected";
import metadataCreationDisabledLabel from "@salesforce/label/c.JT_jtQueryViewer_metadataCreationDisabled";
import advancedOptionStarterFreeLabel from "@salesforce/label/c.JT_jtQueryViewer_advancedOptionStarterFree";
import starterFreeEditionWarningLabel from "@salesforce/label/c.JT_jtQueryViewer_starterFreeEditionWarning";
import enableMetadataEditingProductionLabel from "@salesforce/label/c.JT_jtQueryViewer_enableMetadataEditingProduction";
import dangerLabel from "@salesforce/label/c.JT_jtQueryViewer_danger";
import securityWarningLabel from "@salesforce/label/c.JT_jtQueryViewer_securityWarning";
import apiFeaturesToolingApiLabel from "@salesforce/label/c.JT_jtQueryViewer_apiFeaturesToolingApi";
import toolingApiConsumptionWarningLabel from "@salesforce/label/c.JT_jtQueryViewer_toolingApiConsumptionWarning";
import runAsOwdNoticeLabel from "@salesforce/label/c.JT_jtQueryViewer_runAsOwdNotice";
import findWhereConfigurationUsedLabel from "@salesforce/label/c.JT_jtQueryViewer_findWhereConfigurationUsed";
import runAsUserAdvancedLabel from "@salesforce/label/c.JT_jtQueryViewer_runAsUserAdvanced";
import loadingPreviewLabel from "@salesforce/label/c.JT_jtQueryViewer_loadingPreview";
import dataPreviewTopRecordsLabel from "@salesforce/label/c.JT_jtQueryViewer_dataPreviewTopRecords";
import previousNewLabel from "@salesforce/label/c.JT_jtQueryViewer_previous";
import nextNewLabel from "@salesforce/label/c.JT_jtQueryViewer_next";
import testAssertionLabel from "@salesforce/label/c.JT_jtQueryViewer_testAssertion";
import errorLabel from "@salesforce/label/c.JT_jtQueryViewer_error";
import jsonOutputLabel from "@salesforce/label/c.JT_jtQueryViewer_jsonOutput";
import copyLabel from "@salesforce/label/c.JT_jtQueryViewer_copy";
import downloadCsvLabel from "@salesforce/label/c.JT_jtQueryViewer_downloadCsv";
import downloadCsvFileLabel from "@salesforce/label/c.JT_jtQueryViewer_downloadCsvFile";
import csvFileGeneratedLabel from "@salesforce/label/c.JT_jtQueryViewer_csvFileGenerated";
import cancelNewLabel from "@salesforce/label/c.JT_jtQueryViewer_cancel";
import proceedNormallyLabel from "@salesforce/label/c.JT_jtQueryViewer_proceedNormally";
import useBatchProcessingLabel from "@salesforce/label/c.JT_jtQueryViewer_useBatchProcessing";
import orgTypeDeveloperEditionLabel from "@salesforce/label/c.JT_jtQueryViewer_orgTypeDeveloperEdition";
import orgTypeSandboxLabel from "@salesforce/label/c.JT_jtQueryViewer_orgTypeSandbox";
import orgTypeScratchOrgLabel from "@salesforce/label/c.JT_jtQueryViewer_orgTypeScratchOrg";
import orgTypeProductionLabel from "@salesforce/label/c.JT_jtQueryViewer_orgTypeProduction";
import sandboxEnvironmentTitleLabel from "@salesforce/label/c.JT_jtQueryViewer_sandboxEnvironmentTitle";
import scratchOrgTitleLabel from "@salesforce/label/c.JT_jtQueryViewer_scratchOrgTitle";
import developerEditionTitleLabel from "@salesforce/label/c.JT_jtQueryViewer_developerEditionTitle";
import productionEnvironmentTitleLabel from "@salesforce/label/c.JT_jtQueryViewer_productionEnvironmentTitle";
import configurationRequiredLabel from "@salesforce/label/c.JT_jtQueryViewer_configurationRequired";
import pleaseSelectConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_pleaseSelectConfiguration";
import userRequiredLabel from "@salesforce/label/c.JT_jtQueryViewer_userRequired";
import pleaseSelectUserLabel from "@salesforce/label/c.JT_jtQueryViewer_pleaseSelectUser";
import unknownErrorLabel from "@salesforce/label/c.JT_jtQueryViewer_unknownError";
import noConfigurationSelectedLabel from "@salesforce/label/c.JT_jtQueryViewer_noConfigurationSelected";
import pleaseSelectConfigurationToEditLabel from "@salesforce/label/c.JT_jtQueryViewer_pleaseSelectConfigurationToEdit";
import pleaseSelectConfigurationToDeleteLabel from "@salesforce/label/c.JT_jtQueryViewer_pleaseSelectConfigurationToDelete";
import deleteFailedLabel from "@salesforce/label/c.JT_jtQueryViewer_deleteFailed";
import configurationDeletedLabel from "@salesforce/label/c.JT_jtQueryViewer_configurationDeleted";
import executionErrorLabel from "@salesforce/label/c.JT_jtQueryViewer_executionError";
import queryErrorLabel from "@salesforce/label/c.JT_jtQueryViewer_queryError";
import riskAssessmentFailedLabel from "@salesforce/label/c.JT_jtQueryViewer_riskAssessmentFailed";
import errorUpdatingSettingsLabel from "@salesforce/label/c.JT_jtQueryViewer_errorUpdatingSettings";
import testExecutionTimeoutLabel from "@salesforce/label/c.JT_jtQueryViewer_testExecutionTimeout";
import testExecutionTimeoutMessageLabel from "@salesforce/label/c.JT_jtQueryViewer_testExecutionTimeoutMessage";
import pollingErrorLabel from "@salesforce/label/c.JT_jtQueryViewer_pollingError";
import errorLoadingUsersLabel from "@salesforce/label/c.JT_jtQueryViewer_errorLoadingUsers";
import failedToLoadUsersLabel from "@salesforce/label/c.JT_jtQueryViewer_failedToLoadUsers";
import executionInProgressLabel from "@salesforce/label/c.JT_jtQueryViewer_executionInProgress";
import pleaseWaitForExecutionLabel from "@salesforce/label/c.JT_jtQueryViewer_pleaseWaitForExecution";
import errorExtractingParametersLabel from "@salesforce/label/c.JT_jtQueryViewer_errorExtractingParameters";
import searchErrorLabel from "@salesforce/label/c.JT_jtQueryViewer_searchError";
import partialResultsLabel from "@salesforce/label/c.JT_jtQueryViewer_partialResults";
import partialResultsMessageLabel from "@salesforce/label/c.JT_jtQueryViewer_partialResultsMessage";
import productionEditingEnabledLabel from "@salesforce/label/c.JT_jtQueryViewer_productionEditingEnabled";
import productionEditingDisabledLabel from "@salesforce/label/c.JT_jtQueryViewer_productionEditingDisabled";
import testPassedFoundRecordsLabel from "@salesforce/label/c.JT_jtQueryViewer_testPassedFoundRecords";
import testPassedExecutionTimeLabel from "@salesforce/label/c.JT_jtQueryViewer_testPassedExecutionTime";
import failedToUpdateSettingsLabel from "@salesforce/label/c.JT_jtQueryViewer_failedToUpdateSettings";
import developerEditionLabel from "@salesforce/label/c.JT_jtQueryViewer_developerEdition";
import collapseLabel from "@salesforce/label/c.JT_jtQueryViewer_collapse";
import expandLabel from "@salesforce/label/c.JT_jtQueryViewer_expand";
import failedToExtractParametersLabel from "@salesforce/label/c.JT_jtQueryViewer_failedToExtractParameters";
import failedToPollTestResultsLabel from "@salesforce/label/c.JT_jtQueryViewer_failedToPollTestResults";
import testExecutionFailedLabel from "@salesforce/label/c.JT_jtQueryViewer_testExecutionFailed";
import failedToDeleteConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_failedToDeleteConfiguration";
import confirmDeleteConfigurationLabel from "@salesforce/label/c.JT_jtQueryViewer_confirmDeleteConfiguration";
import confirmDeleteTitleLabel from "@salesforce/label/c.JT_jtQueryViewer_confirmDeleteTitle";
import LightningConfirm from "lightning/confirm";
import failedToExecuteSearchOrchestratorLabel from "@salesforce/label/c.JT_jtQueryViewer_failedToExecuteSearchOrchestrator";
import errorClearingCacheLabel from "@salesforce/label/c.JT_jtQueryViewer_errorClearingCache";
import toolingApiSetupInstructionsLabel from "@salesforce/label/c.JT_jtQueryViewer_toolingApiSetupInstructions";
import errorTitleLabel from "@salesforce/label/c.JT_jtUtils_errorTitle";
import deploymentStartedLabel from "@salesforce/label/c.JT_jtQueryViewer_deploymentStarted";
import deploymentDeletionInProgressLabel from "@salesforce/label/c.JT_jtQueryViewer_deploymentDeletionInProgress";
import deploymentInProgressLabel from "@salesforce/label/c.JT_jtQueryViewer_deploymentInProgress";
import deploymentInitiatedLabel from "@salesforce/label/c.JT_jtQueryViewer_deploymentInitiated";
import configurationActionSuccessfullyLabel from "@salesforce/label/c.JT_jtQueryViewer_configurationActionSuccessfully";
import metadataDeploymentCompletedLabel from "@salesforce/label/c.JT_jtQueryViewer_metadataDeploymentCompleted";
import listUpdatedLabel from "@salesforce/label/c.JT_jtQueryViewer_listUpdated";
import configurationListRefreshedLabel from "@salesforce/label/c.JT_jtQueryViewer_configurationListRefreshed";
import deploymentFailedCheckStatusLabel from "@salesforce/label/c.JT_jtQueryViewer_deploymentFailedCheckStatus";
import actionFailedLabel from "@salesforce/label/c.JT_jtQueryViewer_actionFailed";
import deploymentStatusCheckFailedLabel from "@salesforce/label/c.JT_jtQueryViewer_deploymentStatusCheckFailed";
import failedToCheckDeploymentStatusLabel from "@salesforce/label/c.JT_jtQueryViewer_failedToCheckDeploymentStatus";
import deploymentTimeoutLabel from "@salesforce/label/c.JT_jtQueryViewer_deploymentTimeout";
import deploymentTimeoutMessageLabel from "@salesforce/label/c.JT_jtQueryViewer_deploymentTimeoutMessage";

// Apex imports
import getConfigurations from "@salesforce/apex/JT_QueryViewerController.getConfigurations";
import extractParameters from "@salesforce/apex/JT_QueryViewerController.extractParameters";
import executeQuery from "@salesforce/apex/JT_QueryViewerController.executeQuery";
import canUseRunAs from "@salesforce/apex/JT_QueryViewerController.canUseRunAs";
import getAllActiveUsers from "@salesforce/apex/JT_QueryViewerController.getAllActiveUsers";
import executeAsUser from "@salesforce/apex/JT_RunAsTestExecutor.executeAsUser";
import executeAsPersona from "@salesforce/apex/JT_RunAsTestExecutor.executeAsPersona";
import getPersonaOptions from "@salesforce/apex/JT_RunAsTestExecutor.getPersonaOptions";
import getTestResults from "@salesforce/apex/JT_RunAsTestExecutor.getTestResults";
import canUseRunAsTest from "@salesforce/apex/JT_RunAsTestExecutor.canUseRunAsTest";
import isSandboxOrScratch from "@salesforce/apex/JT_MetadataCreator.isSandboxOrScratch";
import getOrgInfo from "@salesforce/apex/JT_MetadataCreator.getOrgInfo";
import createConfiguration from "@salesforce/apex/JT_MetadataCreator.createConfiguration";
import updateConfiguration from "@salesforce/apex/JT_MetadataCreator.updateConfiguration";
import deleteConfiguration from "@salesforce/apex/JT_MetadataCreator.deleteConfiguration";
import checkDeploymentStatus from "@salesforce/apex/JT_MetadataCreator.checkDeploymentStatus";
import updateProductionEditingSetting from "@salesforce/apex/JT_ProductionSettingsController.updateProductionEditingSetting";
import getUsageTrackingSetting from "@salesforce/apex/JT_ProductionSettingsController.getUsageTrackingSetting";
import updateUsageTrackingSetting from "@salesforce/apex/JT_ProductionSettingsController.updateUsageTrackingSetting";
import logUsageSearch from "@salesforce/apex/JT_ProductionSettingsController.logUsageSearch";
import findAllUsagesWithContinuation from "@salesforce/apexContinuation/JT_UsageFinder.findAllUsagesWithContinuation";
import assessQueryRisk from "@salesforce/apex/JT_QueryViewerController.assessQueryRisk";
import executeQueryWithBatchProcessing from "@salesforce/apex/JT_QueryViewerController.executeQueryWithBatchProcessing";

export default class JtQueryViewer extends LightningElement {
  @track selectedConfig = "";
  @track baseQuery = "";
  @track bindings = "";
  @track parameters = [];
  @track parameterValues = {};
  @track queryResults = [];
  @track columns = [];
  @track recordCount = 0;
  @track isLoading = false;
  @track hasResults = false;
  @track errorMessage = "";
  @track currentPage = 1;
  @track pageSize = 10;
  @track totalPages = 1;
  @track showError = false;
  @track objectName = "";
  @track viewMode = { table: true, json: false, csv: false };
  @track jsonOutput = "";
  expandedCards = new Set();
  @track showRunAs = false;
  @track queryPreviewData = [];
  @track previewColumns = [];
  @track isLoadingPreview = false;
  @track showPreviewData = false;
  @track previewRecordCount = 0;
  @track previewCurrentPage = 1;
  @track previewPageSize = 3; // Show 3 records at a time
  @track previewTotalPages = 1;
  @track runAsUserId = "";
  @track runAsUserName = "";
  @track userOptions = []; // All active users for combobox
  @track isLoadingUsers = false;
  @track showRunAsTest = false;
  @track isRunningTest = false;
  @track personaOptions = [];
  @track runAsPersonaDevName = "";
  @track isLoadingPersonas = false;
  @track runAsMode = "user"; // "user" | "persona"
  @track showPersonaManager = false;
  @track testJobId = "";
  @track testAssertMessage = "";
  @track showTestResults = false;
  @track showCreateModal = false;
  @track isEditMode = false;
  @track canCreateMetadata = false;
  @track configModalMode = "create"; // 'create' | 'edit'
  @track showUsageModal = false;
  @track usageResults = [];
  @track isLoadingUsage = false;
  @track usageServiceErrors = { apex: null, flow: null };
  @track hasPartialUsageResults = false;

  // Debug mode for dropdown styling (disabled - CSS fixed)
  dropdownDebugMode = false;
  @track usageTrackingEnabled = false;
  @track productionOverrideEnabled = false;
  @track isUpdatingSettings = false;
  @track orgInfo = {};
  @track newConfig = {
    label: "",
    developerName: "",
    baseQuery: "",
    bindings: "",
    objectName: ""
  };
  @track originalDevName = ""; // For edit mode
  @track queryValidation = { isValid: false, message: "" };
  @track isSaving = false;
  @track isDeletingConfiguration = false;
  @track showCacheModal = false;
  @track isLoadingQueryPreview = false;
  @track queryPreviewResults = [];
  @track queryPreviewColumns = [];

  // Initial loading state - blocks UI until all wire methods complete
  @track isInitialLoading = true;
  @track initialLoadComplete = {
    configurations: false,
    orgInfo: false,
    sandboxCheck: false,
    runAsCheck: false,
    runAsTestCheck: false
  };

  // Query Risk Assessment
  @track showRiskWarningModal = false;
  @track queryRiskAssessment = null;
  @track isAssessingRisk = false;
  @track pendingExecutionMode = "normal"; // 'normal' or 'batch'

  // Store wired results for refreshing
  wiredConfigsResult;
  wiredUsersResult;
  @track developerNameManuallyEdited = false; // Track if user manually edited dev name

  configurationOptions = [];
  wiredConfigurationsResult;
  searchTimeout;
  pollInterval;

  // Custom Labels organized using getLabels() utility
  labels = getLabels("jtQueryViewer", {
    apexClass: apexClassLabel,
    autoDetectedFromQuery: autoDetectedFromQueryLabel,
    baseQuery: baseQueryLabel,
    bindings: bindingsLabel,
    cacheCleared: cacheClearedLabel,
    cacheClearedDetail: cacheClearedDetailLabel,
    cancel: cancelLabel,
    chooseConfiguration: chooseConfigurationLabel,
    clear: clearLabel,
    clearCache: clearCacheLabel,
    clearCacheButton: clearCacheButtonLabel,
    clearCacheDescription: clearCacheDescriptionLabel,
    clearCacheTitle: clearCacheTitleLabel,
    clearCacheWarning: clearCacheWarningLabel,
    clearConfigurationsHelp: clearConfigurationsHelpLabel,
    clearConfigurationsLabel: clearConfigurationsLabelLabel,
    clearRecentHelp: clearRecentHelpLabel,
    clearRecentLabel: clearRecentLabelLabel,
    clearResultsHelp: clearResultsHelpLabel,
    clearResultsLabel: clearResultsLabelLabel,
    clearSelection: clearSelectionLabel,
    clearUsersHelp: clearUsersHelpLabel,
    clearUsersLabel: clearUsersLabelLabel,
    code: codeLabel,
    createConfigTooltip: createConfigTooltipLabel,
    createNewConfiguration: createNewConfigurationLabel,
    developerName: developerNameLabel,
    developerNameCannotEndWithUnderscore:
      developerNameCannotEndWithUnderscoreLabel,
    developerNameInvalidChars: developerNameInvalidCharsLabel,
    developerNameMustStartWithLetter: developerNameMustStartWithLetterLabel,
    developerNameNoConsecutiveUnderscores:
      developerNameNoConsecutiveUnderscoresLabel,
    developerNameRequired: developerNameRequiredLabel,
    developerNameTooLong: developerNameTooLongLabel,
    editConfiguration: editConfigurationLabel,
    executeQuery: executeQueryLabel,
    executeSystemRunAs: executeSystemRunAsLabel,
    executingTest: executingTestLabel,
    findingUsage: findingUsageLabel,
    foundReferences: foundReferencesLabel,
    invalidQuery: invalidQueryLabel,
    label: labelLabel,
    labelRequired: labelRequiredLabel,
    labelTooLong: labelTooLongLabel,
    line: lineLabel,
    lineNumber: lineNumberLabel,
    loadingUsers: loadingUsersLabel,
    name: nameLabel,
    next: nextLabel,
    noParametersRequired: noParametersRequiredLabel,
    noReferencesFound: noReferencesFoundLabel,
    noResults: noResultsLabel,
    noUsageFound: noUsageFoundLabel,
    noUsageMessage: noUsageMessageLabel,
    object: objectLabel,
    objectName: objectNameLabel,
    objectNameReadOnly: objectNameReadOnlyLabel,
    of: ofLabel,
    page: pageLabel,
    predefinedBindings: predefinedBindingsLabel,
    predefinedBindingsDesc: predefinedBindingsDescLabel,
    previous: previousLabel,
    queryParameters: queryParametersLabel,
    queryPreview: queryPreviewLabel,
    queryPreviewTitle: queryPreviewTitleLabel,
    record: recordLabel,
    records: recordsLabel,
    results: resultsLabel,
    runAsNote: runAsNoteLabel,
    runAsUser: runAsUserLabel,
    sandboxOnlyWarning: sandboxOnlyWarningLabel,
    save: saveLabel,
    searchConfigsPlaceholder: searchConfigsPlaceholderLabel,
    searchUsersPlaceholder: searchUsersPlaceholderLabel,
    searchingFlows: searchingFlowsLabel,
    searchingUsageMessage: searchingUsageMessageLabel,
    selectAll: selectAllLabel,
    selectConfiguration: selectConfigurationLabel,
    selectOption: selectOptionLabel,
    selectUser: selectUserLabel,
    setupRequired: setupRequiredLabel,
    namedCredentialSetup: namedCredentialSetupLabel,
    toolingApiSetupLink: toolingApiSetupLinkLabel,
    showing: showingLabel,
    toolingAPINote: toolingAPINoteLabel,
    type: typeLabel,
    typeToFilter: typeToFilterLabel,
    updateConfiguration: updateConfigurationLabel,
    usageModalSubtitle: usageModalSubtitleLabel,
    usageModalTitle: usageModalTitleLabel,
    validQuery: validQueryLabel,
    validSOQLSyntax: validSOQLSyntaxLabel,
    whereIsThisUsed: whereIsThisUsedLabel,
    whereIsThisUsedTooltip: whereIsThisUsedTooltipLabel,
    skipToMainContent: skipToMainContentLabel,
    loadingApplication: loadingApplicationLabel,
    loadingDynamicQueryViewer: loadingDynamicQueryViewerLabel,
    searchingForUsage: searchingForUsageLabel,
    searching: searchingLabel,
    dynamicQueryViewer: dynamicQueryViewerLabel,
    clearCacheAndRefresh: clearCacheAndRefreshLabel,
    openCacheManagementModal: openCacheManagementModalLabel,
    createConfiguration: createConfigurationLabel,
    createNewQueryConfiguration: createNewQueryConfigurationLabel,
    createNewQueryConfigurationAria: createNewQueryConfigurationAriaLabel,
    editConfigurationNew: editConfigurationNewLabel,
    editSelectedConfiguration: editSelectedConfigurationLabel,
    editSelectedQueryConfigurationAria: editSelectedQueryConfigurationAriaLabel,
    deleteConfiguration: deleteConfigurationLabel,
    deleteSelectedConfiguration: deleteSelectedConfigurationLabel,
    deleteSelectedQueryConfigurationAria:
      deleteSelectedQueryConfigurationAriaLabel,
    production: productionLabel,
    readOnlyModeInProduction: readOnlyModeInProductionLabel,
    queryViewerMainContent: queryViewerMainContentLabel,
    warning: warningLabel,
    productionEnvironmentDetected: productionEnvironmentDetectedLabel,
    metadataCreationDisabled: metadataCreationDisabledLabel,
    advancedOptionStarterFree: advancedOptionStarterFreeLabel,
    starterFreeEditionWarning: starterFreeEditionWarningLabel,
    enableMetadataEditingProduction: enableMetadataEditingProductionLabel,
    danger: dangerLabel,
    securityWarning: securityWarningLabel,
    apiFeaturesToolingApi: apiFeaturesToolingApiLabel,
    toolingApiConsumptionWarning: toolingApiConsumptionWarningLabel,
    runAsOwdNotice: runAsOwdNoticeLabel,
    findWhereConfigurationUsed: findWhereConfigurationUsedLabel,
    runAsUserAdvanced: runAsUserAdvancedLabel,
    loadingPreview: loadingPreviewLabel,
    dataPreviewTopRecords: dataPreviewTopRecordsLabel,
    previousNew: previousNewLabel,
    nextNew: nextNewLabel,
    testAssertion: testAssertionLabel,
    error: errorLabel,
    jsonOutput: jsonOutputLabel,
    copy: copyLabel,
    downloadCsv: downloadCsvLabel,
    downloadCsvFile: downloadCsvFileLabel,
    csvFileGenerated: csvFileGeneratedLabel,
    cancelNew: cancelNewLabel,
    proceedNormally: proceedNormallyLabel,
    useBatchProcessing: useBatchProcessingLabel,
    orgTypeDeveloperEdition: orgTypeDeveloperEditionLabel,
    orgTypeSandbox: orgTypeSandboxLabel,
    orgTypeScratchOrg: orgTypeScratchOrgLabel,
    orgTypeProduction: orgTypeProductionLabel,
    sandboxEnvironmentTitle: sandboxEnvironmentTitleLabel,
    scratchOrgTitle: scratchOrgTitleLabel,
    developerEditionTitle: developerEditionTitleLabel,
    productionEnvironmentTitle: productionEnvironmentTitleLabel,
    configurationRequired: configurationRequiredLabel,
    pleaseSelectConfiguration: pleaseSelectConfigurationLabel,
    userRequired: userRequiredLabel,
    pleaseSelectUser: pleaseSelectUserLabel,
    unknownError: unknownErrorLabel,
    noConfigurationSelected: noConfigurationSelectedLabel,
    errorTitle: errorTitleLabel,
    errorClearingCache: errorClearingCacheLabel,
    toolingApiSetupInstructions: toolingApiSetupInstructionsLabel,
    pleaseSelectConfigurationToEdit: pleaseSelectConfigurationToEditLabel,
    pleaseSelectConfigurationToDelete: pleaseSelectConfigurationToDeleteLabel,
    deleteFailed: deleteFailedLabel,
    configurationDeleted: configurationDeletedLabel,
    executionError: executionErrorLabel,
    queryError: queryErrorLabel,
    riskAssessmentFailed: riskAssessmentFailedLabel,
    errorUpdatingSettings: errorUpdatingSettingsLabel,
    testExecutionTimeout: testExecutionTimeoutLabel,
    testExecutionTimeoutMessage: testExecutionTimeoutMessageLabel,
    pollingError: pollingErrorLabel,
    errorLoadingUsers: errorLoadingUsersLabel,
    failedToLoadUsers: failedToLoadUsersLabel,
    executionInProgress: executionInProgressLabel,
    pleaseWaitForExecution: pleaseWaitForExecutionLabel,
    errorExtractingParameters: errorExtractingParametersLabel,
    searchError: searchErrorLabel,
    partialResults: partialResultsLabel,
    partialResultsMessage: partialResultsMessageLabel,
    productionEditingEnabled: productionEditingEnabledLabel,
    productionEditingDisabled: productionEditingDisabledLabel,
    testPassedFoundRecords: testPassedFoundRecordsLabel,
    testPassedExecutionTime: testPassedExecutionTimeLabel,
    failedToUpdateSettings: failedToUpdateSettingsLabel,
    developerEdition: developerEditionLabel,
    collapse: collapseLabel,
    expand: expandLabel,
    failedToExtractParameters: failedToExtractParametersLabel,
    failedToPollTestResults: failedToPollTestResultsLabel,
    testExecutionFailed: testExecutionFailedLabel,
    validSoqlSyntax: validSOQLSyntaxLabel,
    failedToDeleteConfiguration: failedToDeleteConfigurationLabel,
    failedToExecuteSearchOrchestrator: failedToExecuteSearchOrchestratorLabel,
    confirmDeleteConfiguration: confirmDeleteConfigurationLabel,
    confirmDeleteTitle: confirmDeleteTitleLabel,
    deploymentStarted: deploymentStartedLabel,
    deploymentDeletionInProgress: deploymentDeletionInProgressLabel,
    deploymentInProgress: deploymentInProgressLabel,
    deploymentInitiated: deploymentInitiatedLabel,
    configurationActionSuccessfully: configurationActionSuccessfullyLabel,
    metadataDeploymentCompleted: metadataDeploymentCompletedLabel,
    listUpdated: listUpdatedLabel,
    configurationListRefreshed: configurationListRefreshedLabel,
    deploymentFailedCheckStatus: deploymentFailedCheckStatusLabel,
    actionFailed: actionFailedLabel,
    deploymentStatusCheckFailed: deploymentStatusCheckFailedLabel,
    failedToCheckDeploymentStatus: failedToCheckDeploymentStatusLabel,
    deploymentTimeout: deploymentTimeoutLabel,
    deploymentTimeoutMessage: deploymentTimeoutMessageLabel
  });

  // Wire to get all configurations (cacheable for refreshApex)
  @wire(getConfigurations)
  wiredConfigurations(result) {
    this.wiredConfigurationsResult = result;
    const { data } = result;

    if (data) {
      // Force new array reference to ensure reactivity in child components
      this.configurationOptions = [...data];
      this.filteredConfigs = [...data]; // Initialize filtered list
      this.showError = false;
    } else if (result.error) {
      console.error("❌ Error loading configurations:", result.error);
      this.showError = true;
    }

    // Mark configurations as loaded (even if error, we still show UI)
    this.initialLoadComplete.configurations = true;
    this.checkInitialLoadComplete();
  }

  // Wire to check if org allows metadata creation
  @wire(isSandboxOrScratch)
  wiredIsSandbox({ data }) {
    if (data !== undefined) {
      this.canCreateMetadata = data;
    }

    // Mark sandbox check as complete
    this.initialLoadComplete.sandboxCheck = true;
    this.checkInitialLoadComplete();
  }

  // Wire to get org info
  @wire(getOrgInfo)
  wiredOrgInfo({ data }) {
    if (data) {
      this.orgInfo = data;
      this.canCreateMetadata = data.canCreateMetadata;
      this.productionOverrideEnabled = data.productionOverrideEnabled || false;
    }

    // Mark org info as loaded (even if error, we still show UI)
    this.initialLoadComplete.orgInfo = true;
    this.checkInitialLoadComplete();
  }

  get isProduction() {
    return this.orgInfo && this.orgInfo.isProduction === true;
  }

  // Handle production override toggle
  handleProductionOverrideChange(event) {
    const enabled = event.target.checked;
    this.isUpdatingSettings = true;

    updateProductionEditingSetting({ enabled: enabled })
      .then(() => {
        this.productionOverrideEnabled = enabled;
        showSuccessToast(
          this,
          enabled
            ? this.labels.productionEditingEnabled
            : this.labels.productionEditingDisabled
        );

        // Refresh org info
        return refreshApex(this.wiredConfigurationsResult);
      })
      .catch((error) => {
        showErrorToast(
          this,
          this.labels.errorUpdatingSettings,
          extractErrorMessage(error, "Failed to update settings")
        );
        // Revert checkbox
        this.productionOverrideEnabled = !enabled;
      })
      .finally(() => {
        this.isUpdatingSettings = false;
      });
  }

  get orgTypeBadge() {
    if (!this.orgInfo) return "";
    const orgType = this.orgInfo.organizationType || "";

    if (this.orgInfo.isSandbox) return this.labels.orgTypeSandbox;
    if (this.orgInfo.isScratch) return this.labels.orgTypeScratchOrg;
    if (orgType === this.labels.developerEdition)
      return this.labels.orgTypeDeveloperEdition;

    // All other orgs are considered production (including Starter/Free)
    return this.labels.orgTypeProduction;
  }

  get orgTypeBadgeTitle() {
    const orgType = this.orgInfo?.organizationType || "";
    if (this.orgInfo?.isSandbox) return this.labels.sandboxEnvironmentTitle;
    if (this.orgInfo?.isScratch) return this.labels.scratchOrgTitle;
    if (orgType === this.labels.developerEdition)
      return this.labels.developerEditionTitle;
    return this.labels.productionEnvironmentTitle;
  }

  // Wire to check if user can use Run As feature
  @wire(canUseRunAs)
  wiredCanUseRunAs({ error, data }) {
    if (data) {
      this.showRunAs = data;
      // Load all users when Run As is available
      if (data && this.userOptions.length === 0) {
        this.loadAllUsers();
      }
    } else if (error) {
      this.showRunAs = false;
    }

    // Mark run as check as complete
    this.initialLoadComplete.runAsCheck = true;
    this.checkInitialLoadComplete();
  }

  // Wire to check if user can use Run As Test feature
  @wire(canUseRunAsTest)
  wiredCanUseRunAsTest({ error, data }) {
    if (data) {
      this.showRunAsTest = data;
    } else if (error) {
      this.showRunAsTest = false;
    }

    // Mark run as test check as complete
    this.initialLoadComplete.runAsTestCheck = true;
    this.checkInitialLoadComplete();
  }

  /**
   * @description Checks if all initial wire methods have completed
   * Hides the initial loading spinner when all critical data is loaded
   */
  checkInitialLoadComplete() {
    const allComplete =
      this.initialLoadComplete.configurations &&
      this.initialLoadComplete.orgInfo &&
      this.initialLoadComplete.sandboxCheck &&
      this.initialLoadComplete.runAsCheck &&
      this.initialLoadComplete.runAsTestCheck;

    if (allComplete && this.isInitialLoading) {
      // Small delay to ensure smooth transition
      setTimeout(() => {
        this.isInitialLoading = false;
      }, 100);
    }
  }

  // Load all active users for dropdown (called once)
  loadAllUsers() {
    this.isLoadingUsers = true;
    getAllActiveUsers()
      .then((users) => {
        this.userOptions = users.map((user) => ({
          label: user.label,
          value: user.value
        }));
      })
      .catch((error) => {
        showErrorToast(
          this,
          this.labels.errorLoadingUsers,
          extractErrorMessage(error, this.labels.failedToLoadUsers)
        );
        this.userOptions = [];
      })
      .finally(() => {
        this.isLoadingUsers = false;
      });
  }

  get hasConfigurations() {
    return this.configurationOptions && this.configurationOptions.length > 0;
  }

  /**
   * @description Checks if any modal is currently open
   * Used to prevent initial loading spinner from appearing over modals
   * @return Boolean True if any modal is open
   */
  get hasOpenModals() {
    return (
      this.showUsageModal ||
      this.showCreateModal ||
      this.showCacheModal ||
      this.showRiskWarningModal
    );
  }

  get searchingUsageMessage() {
    if (!this.selectedConfig) {
      return this.labels.searchingUsageMessage.replace("{0}", "");
    }
    return this.labels.searchingUsageMessage.replace(
      "{0}",
      this.selectedConfig
    );
  }

  get dataPreviewTitleFormatted() {
    return this.labels.dataPreviewTopRecords.replace(
      "{0}",
      this.previewRecordCount
    );
  }

  get csvFileGeneratedMessage() {
    return this.labels.csvFileGenerated.replace("{0}", this.recordCount);
  }

  get hasParameters() {
    return this.parameters && this.parameters.length > 0;
  }

  get queryPreview() {
    if (!this.baseQuery) return "";
    return this.baseQuery;
  }

  // Preview pagination getters
  get previewPaginatedData() {
    const start = (this.previewCurrentPage - 1) * this.previewPageSize;
    const end = start + this.previewPageSize;
    return this.queryPreviewData.slice(start, end);
  }

  get showPreviewPagination() {
    return this.previewRecordCount > this.previewPageSize;
  }

  get previewHasPrevious() {
    return this.previewCurrentPage > 1;
  }

  get previewHasNext() {
    return this.previewCurrentPage < this.previewTotalPages;
  }

  get previewPageInfo() {
    return `Page ${this.previewCurrentPage} of ${this.previewTotalPages} (${this.previewRecordCount} records)`;
  }

  // Preview pagination handlers
  handlePreviewPrevious() {
    if (this.previewHasPrevious) {
      this.previewCurrentPage--;
    }
  }

  handlePreviewNext() {
    if (this.previewHasNext) {
      this.previewCurrentPage++;
    }
  }

  get hasBindings() {
    return this.bindings && this.bindings.trim() !== "";
  }

  get showResults() {
    return this.hasResults && !this.isLoading;
  }

  // Phase 1 Refactor: Removed obsolete getters (moved to jtSearchableCombobox)

  get recordCountLabel() {
    return this.recordCount !== 1 ? this.labels.records : this.labels.record;
  }

  // View mode computed properties
  get isTableView() {
    return this.viewMode.table ? "brand" : "neutral";
  }

  get isJsonView() {
    return this.viewMode.json ? "brand" : "neutral";
  }

  get isCsvView() {
    return this.viewMode.csv ? "brand" : "neutral";
  }

  // Pagination computed properties
  get paginatedResults() {
    if (!this.queryResults || this.queryResults.length === 0) {
      return [];
    }
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;

    // Enhance results for mobile cards and table
    return this.queryResults.slice(start, end).map((row, index) => {
      const rowNumber = start + index + 1;
      const displayName = row.Name || row.Id || `Record ${rowNumber}`;
      const isExpanded = this.expandedCards.has(row.Id);

      // Pre-compute cell values for template (LWC doesn't support computed property access)
      const cells = this.columns.map((col) => ({
        key: col.fieldName,
        label: col.label,
        value: row[col.fieldName] || ""
      }));

      return {
        ...row,
        _rowNumber: rowNumber,
        _displayName: displayName,
        _expanded: isExpanded,
        _expandIcon: isExpanded
          ? "utility:chevrondown"
          : "utility:chevronright",
        _expandLabel: isExpanded ? this.labels.collapse : this.labels.expand,
        _cells: cells
      };
    });
  }

  get showPagination() {
    return this.recordCount > this.pageSize;
  }

  get isFirstPage() {
    return this.currentPage === 1;
  }

  get isLastPage() {
    return this.currentPage >= this.totalPages;
  }

  get firstRecordIndex() {
    return this.queryResults.length > 0
      ? (this.currentPage - 1) * this.pageSize + 1
      : 0;
  }

  get lastRecordIndex() {
    const last = this.currentPage * this.pageSize;
    return last > this.recordCount ? this.recordCount : last;
  }

  get currentPageDisplay() {
    return `${this.labels.page} ${this.currentPage} / ${this.totalPages}`;
  }

  // Pagination handlers
  handlePreviousPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
    }
  }

  resetPagination() {
    this.currentPage = 1;
    this.totalPages = Math.ceil(this.recordCount / this.pageSize);
  }

  // Handle configuration selection
  // Phase 1 Refactor: Config dropdown logic moved to jtSearchableCombobox

  // Phase 1 Refactor: Updated to use generic combobox event
  handleConfigSelect(event) {
    const { value, data } = event.detail; // label unused

    this.selectedConfig = value;
    this.baseQuery = data.baseQuery;
    this.bindings = data.bindings;
    this.objectName = data.objectName;

    // Only extract parameters if bindings are NOT predefined
    if (!this.hasBindings) {
      this.extractQueryParameters();
    } else {
      // Clear parameters if bindings are predefined
      this.parameters = [];
      this.parameterValues = {};
    }

    this.resetResults();
  }

  // Phase 1 Refactor: Clear configuration
  handleConfigClear() {
    this.selectedConfig = null;
    this.baseQuery = "";
    this.bindings = null;
    this.objectName = "";
    this.parameters = [];
    this.parameterValues = {};
    this.resetResults();
  }

  // Extract parameters from the query
  extractQueryParameters() {
    if (this.baseQuery) {
      extractParameters({ query: this.baseQuery })
        .then((result) => {
          this.parameters = result.map((param) => ({
            name: param,
            label: param, // Use exact parameter name from SOQL
            value: ""
          }));
          this.parameterValues = {};
        })
        .catch((error) => {
          showErrorToast(
            this,
            this.labels.errorExtractingParameters,
            extractErrorMessage(error, this.labels.failedToExtractParameters)
          );
        });
    }
  }

  // Phase 2 Refactor: Updated to use jtParameterInputs event
  handleParameterChange(event) {
    const { allValues } = event.detail;

    // 🛡️ CRITICAL FIX: Validate allValues exists
    // This prevents native 'change' event from overwriting with undefined
    if (!allValues || typeof allValues !== "object") {
      return; // Early exit - ignore native change events
    }

    this.parameterValues = allValues;
  }

  // Handle user selection from dropdown
  // Phase 1 Refactor: User dropdown logic moved to jtSearchableCombobox

  // Phase 1 Refactor: Updated to use generic combobox event
  handleUserSelect(event) {
    const { value, label } = event.detail;

    this.runAsUserId = value;
    this.runAsUserName = label;
  }

  // Phase 1 Refactor: Clear user selection (from combobox)
  handleUserClear() {
    this.handleClearRunAs();
  }

  handlePersonaSelect(event) {
    const { value, label } = event.detail;
    this.runAsPersonaDevName = value;
    this.runAsUserName = label;
  }

  handlePersonaClear() {
    this.runAsPersonaDevName = "";
    this.runAsUserName = "";
  }

  handleManagePersonas() {
    this.showPersonaManager = true;
  }

  handlePersonaManagerClose() {
    this.showPersonaManager = false;
  }

  handlePersonaConfigSaved() {
    // Reload persona options after deploy enqueued
    this.isLoadingPersonas = true;
    getPersonaOptions()
      .then((options) => {
        this.personaOptions = options;
      })
      .catch((error) => {
        console.error("Error reloading persona options:", error);
      })
      .finally(() => {
        this.isLoadingPersonas = false;
      });
  }

  handleModeChange(event) {
    const { mode } = event.detail;
    this.runAsMode = mode;

    if (mode === "persona" && this.personaOptions.length === 0) {
      this.isLoadingPersonas = true;
      getPersonaOptions()
        .then((options) => {
          this.personaOptions = options;
        })
        .catch((error) => {
          console.error("Error loading persona options:", error);
        })
        .finally(() => {
          this.isLoadingPersonas = false;
        });
    }
  }

  // Clear Run As user and all related data
  handleClearRunAs() {
    // Clear user and persona selection
    this.runAsUserId = "";
    this.runAsUserName = "";
    this.runAsPersonaDevName = "";

    // ✅ Always clear query results when Run As User is cleared
    // This ensures UI is properly reset regardless of state
    this.queryResults = [];
    this.hasResults = false;
    this.recordCount = 0;
    this.columns = [];
    this.currentPage = 1;
    this.jsonOutput = "";
    this.showError = false;
    this.errorMessage = "";

    // Clear test execution state
    this.isRunningTest = false;
    this.testJobId = "";
    this.testAssertMessage = "";
    this.showTestResults = false;

    // Clear query preview data
    this.queryPreviewData = [];
    this.previewColumns = [];
    this.showPreviewData = false;
    this.previewRecordCount = 0;
    this.previewCurrentPage = 1;

    // Stop any polling
    if (this.pollInterval) {
      // pollInterval is now a function (stopPolling), not an interval ID
      if (typeof this.pollInterval === "function") {
        this.pollInterval();
      } else {
        // Fallback for old interval ID format (shouldn't happen, but safe)
        clearInterval(this.pollInterval);
      }
      this.pollInterval = null;
    }
  }

  // Execute query with true System.runAs (test context)
  handleExecuteAsUserTest() {
    // Prevent multiple simultaneous executions
    if (this.isRunningTest) {
      showErrorToast(
        this,
        this.labels.executionInProgress,
        this.labels.pleaseWaitForExecution
      );
      return;
    }

    if (!this.selectedConfig) {
      showErrorToast(
        this,
        this.labels.configurationRequired,
        this.labels.pleaseSelectConfiguration
      );
      return;
    }

    if (!this.runAsUserId) {
      showErrorToast(
        this,
        this.labels.userRequired,
        this.labels.pleaseSelectUser
      );
      return;
    }

    this.isRunningTest = true;
    this.showError = false;
    this.resetResults();
    this.testAssertMessage = "";

    // Build bindings JSON
    const bindingsToSend = this.buildBindingsJson();

    // Execute as user - single call, @future handles DML + callout separation
    executeAsUser({
      userId: this.runAsUserId,
      configName: this.selectedConfig,
      bindingsJson: bindingsToSend
    })
      .then((result) => {
        if (result.success) {
          // result.jobId is the executionId (JT_RunAsTest_Execution__c.Id)
          this.testJobId = result.jobId;
          this.runAsUserName = result.runAsUserName;
          // Start polling for results
          this.startPollingTestResults();
        } else {
          this.showError = true;
          this.errorMessage = result.errorMessage;
          // Error message is displayed in banner below, no need for redundant toast
          this.isRunningTest = false;
        }
      })
      .catch((error) => {
        this.showError = true;
        // Extract error message using utility function
        let errorMsg = extractErrorMessage(error, this.labels.unknownError);

        // If it's a generic "Script-thrown exception", try to get more details
        if (
          errorMsg === "Script-thrown exception" &&
          error.body?.output?.errors
        ) {
          const errors = error.body.output.errors;
          if (errors.length > 0 && errors[0].message) {
            errorMsg = errors[0].message;
          }
        }

        this.errorMessage = errorMsg;
        // Error message is displayed in banner below, no need for redundant toast
        this.isRunningTest = false;
      });
  }

  // Execute query as synthetic persona user (test context)
  handleExecuteAsPersonaTest() {
    if (this.isRunningTest) {
      showErrorToast(
        this,
        this.labels.executionInProgress,
        this.labels.pleaseWaitForExecution
      );
      return;
    }

    if (!this.selectedConfig) {
      showErrorToast(
        this,
        this.labels.configurationRequired,
        this.labels.pleaseSelectConfiguration
      );
      return;
    }

    if (!this.runAsPersonaDevName) {
      showErrorToast(
        this,
        this.labels.userRequired,
        this.labels.pleaseSelectUser
      );
      return;
    }

    this.isRunningTest = true;
    this.showError = false;
    this.resetResults();
    this.testAssertMessage = "";

    const bindingsToSend = this.buildBindingsJson();

    executeAsPersona({
      personaDeveloperName: this.runAsPersonaDevName,
      configName: this.selectedConfig,
      bindingsJson: bindingsToSend
    })
      .then((result) => {
        if (result.success) {
          this.testJobId = result.jobId;
          this.runAsUserName = result.runAsUserName;
          this.startPollingTestResults();
        } else {
          this.showError = true;
          this.errorMessage = result.errorMessage;
          this.isRunningTest = false;
        }
      })
      .catch((error) => {
        this.showError = true;
        let errorMsg = extractErrorMessage(error, this.labels.unknownError);
        if (
          errorMsg === "Script-thrown exception" &&
          error.body?.output?.errors
        ) {
          const errors = error.body.output.errors;
          if (errors.length > 0 && errors[0].message) {
            errorMsg = errors[0].message;
          }
        }
        this.errorMessage = errorMsg;
        this.isRunningTest = false;
      });
  }

  buildBindingsJson() {
    if (this.hasBindings && !this.hasParameters) {
      return this.bindings;
    } else if (this.hasParameters) {
      const paramValues = this.parameterValues || {};

      const hasAnyValues = Object.keys(paramValues).some(
        (key) =>
          paramValues[key] !== "" &&
          paramValues[key] !== null &&
          paramValues[key] !== undefined
      );

      if (!hasAnyValues && this.hasBindings) {
        return this.bindings;
      } else if (!hasAnyValues) {
        return JSON.stringify({});
      }

      const processedValues = this.processParameterValues(paramValues);
      return JSON.stringify(processedValues);
    }
    return null;
  }

  processParameterValues(paramValues) {
    if (!this.baseQuery) {
      return paramValues;
    }

    const normalizedQuery = this.baseQuery.toLowerCase();
    const processed = { ...paramValues };

    for (const key in processed) {
      if (!processed.hasOwnProperty(key)) {
        continue;
      }

      const value = processed[key];

      if (!value || typeof value !== "string") {
        delete processed[key];
        continue;
      }

      const trimmedValue = value.trim();
      if (trimmedValue === "") {
        delete processed[key];
        continue;
      }

      const bindingPattern = `:${key.toLowerCase()}`;
      const inRegex = new RegExp(
        `\\bin\\s*${bindingPattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`,
        "i"
      );
      const notInRegex = new RegExp(
        `\\bnot\\s+in\\s*${bindingPattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`,
        "i"
      );
      const includesRegex = new RegExp(
        `\\bincludes\\s*${bindingPattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`,
        "i"
      );
      const excludesRegex = new RegExp(
        `\\bexcludes\\s*${bindingPattern.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`,
        "i"
      );

      const requiresList =
        inRegex.test(normalizedQuery) ||
        notInRegex.test(normalizedQuery) ||
        includesRegex.test(normalizedQuery) ||
        excludesRegex.test(normalizedQuery);

      if (requiresList) {
        if (trimmedValue.includes(",")) {
          const arrayValue = trimmedValue
            .split(",")
            .map((item) => this.convertToTypedValue(item.trim()))
            .filter(
              (item) => item !== null && item !== undefined && item !== ""
            );
          if (arrayValue.length > 0) {
            processed[key] = arrayValue;
          } else {
            delete processed[key];
          }
        } else {
          const typedValue = this.convertToTypedValue(trimmedValue);
          if (
            typedValue !== null &&
            typedValue !== undefined &&
            typedValue !== ""
          ) {
            processed[key] = [typedValue];
          } else {
            delete processed[key];
          }
        }
      } else {
        const typedValue = this.convertToTypedValue(trimmedValue);
        if (
          typedValue !== null &&
          typedValue !== undefined &&
          typedValue !== ""
        ) {
          processed[key] = typedValue;
        } else {
          delete processed[key];
        }
      }
    }

    return processed;
  }

  /**
   * Converts a string value to its appropriate JavaScript type
   * @param {string} value - String value to convert
   * @returns {string|number|boolean|null} Converted value with appropriate type
   */
  convertToTypedValue(value) {
    if (!value || typeof value !== "string") {
      return value;
    }

    const trimmed = value.trim();
    if (trimmed === "") {
      return null;
    }

    // Check for boolean values (case-insensitive)
    const lowerTrimmed = trimmed.toLowerCase();
    if (lowerTrimmed === "true") {
      return true;
    }
    if (lowerTrimmed === "false") {
      return false;
    }

    // Check for Salesforce ID (15 or 18 characters, alphanumeric)
    // IDs start with letters and are typically 15 or 18 chars
    const salesforceIdPattern = /^[a-zA-Z0-9]{15}$|^[a-zA-Z0-9]{18}$/;
    if (salesforceIdPattern.test(trimmed)) {
      // Keep as string - IDs should remain strings in SOQL
      return trimmed;
    }

    // Check for date/datetime values
    // ISO 8601 format: YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss.sssZ
    const isoDatePattern =
      /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d{3})?(Z|[+-]\d{2}:\d{2})?)?$/;
    if (isoDatePattern.test(trimmed)) {
      const dateValue = new Date(trimmed);
      if (!isNaN(dateValue.getTime())) {
        // Return ISO string format for Apex to parse
        // Apex expects ISO 8601 format for Date/Datetime
        return dateValue.toISOString();
      }
    }

    // Check for other common date formats (MM/DD/YYYY, DD/MM/YYYY, etc.)
    // Try parsing as date - if valid, convert to ISO format
    const dateValue = new Date(trimmed);
    if (!isNaN(dateValue.getTime())) {
      // Additional validation: check if it's a reasonable date (not just a number)
      // Avoid converting pure numbers like "2024" to dates
      const year = dateValue.getFullYear();
      if (year >= 1900 && year <= 2100) {
        // Check if the original string looks like a date (has separators or is ISO format)
        if (
          trimmed.includes("/") ||
          trimmed.includes("-") ||
          trimmed.includes("T") ||
          isoDatePattern.test(trimmed)
        ) {
          return dateValue.toISOString();
        }
      }
    }

    // Check for numeric values (integers or decimals)
    // Pattern: optional sign, digits, optional decimal point and digits
    const numericPattern = /^-?\d+(\.\d+)?$/;
    if (numericPattern.test(trimmed)) {
      // Check if it's an integer (no decimal point)
      if (trimmed.includes(".")) {
        // Use parseFloat for decimal numbers
        return parseFloat(trimmed);
      } else {
        // Use parseInt for integers
        const num = parseInt(trimmed, 10);
        // Check if it's within safe integer range
        if (Number.isSafeInteger(num)) {
          return num;
        } else {
          // For very large integers outside safe range, use parseFloat to preserve precision
          return parseFloat(trimmed);
        }
      }
    }

    // Return as string if not numeric, boolean, date, or ID
    return trimmed;
  }

  // Start polling for test results
  startPollingTestResults() {
    // Use polling helper utility
    const stopPolling = pollUntilComplete(
      // Poll function
      () => getTestResults({ executionId: this.testJobId }),
      // Check if complete
      (result) => {
        // Keep polling while server signals "please wait" (queued/running/enqueuing)
        const isWaiting =
          result.message &&
          result.message.toLowerCase().includes("please wait");
        if (isWaiting) return false;

        // Stop polling once success is explicitly true or false (terminal state)
        return result.success === true || result.success === false;
      },
      // On complete
      (result) => {
        this.handleTestResults(result);
      },
      // On error
      (error) => {
        this.isRunningTest = false;
        showErrorToast(
          this,
          this.labels.pollingError,
          extractErrorMessage(error, this.labels.failedToPollTestResults)
        );
      },
      // On timeout
      () => {
        this.isRunningTest = false;
        showErrorToast(
          this,
          this.labels.testExecutionTimeout,
          this.labels.testExecutionTimeoutMessage
        );
      },
      // Options
      {
        interval: 2000, // Poll every 2 seconds
        maxPolls: 60 // 120 seconds max (2 sec intervals) - increased for Developer Org test execution delays
      }
    );

    // Store stop function for cleanup
    this.pollInterval = stopPolling;
  }

  // Handle test results
  handleTestResults(result) {
    this.isRunningTest = false;
    this.testAssertMessage = result.assertMessage || "";

    if (result.success) {
      // Parse and display results FIRST
      this.processTestQueryResults(result);

      // Use setTimeout to ensure LWC reactivity processes the state changes
      // This forces a re-render cycle after data is set
      setTimeout(() => {
        // CRITICAL: Set isLoading to false AFTER processTestQueryResults
        // This ensures showResults getter returns true
        this.isLoading = false;
      }, 0);

      // Only show toast for regular execution, not for Run As User
      // Run As User already has its own UI feedback
      // Toast removed - results are already displayed in the UI
      // Previously computed successMsg but no longer needed since toast was removed
    } else {
      // Clear any previous results when there's an error
      this.queryResults = [];
      this.hasResults = false;
      this.recordCount = 0;
      this.columns = [];
      this.showTestResults = false;
      this.testAssertMessage = "";

      this.isLoading = false;
      this.showError = true;
      this.errorMessage =
        result.errorMessage || this.labels.testExecutionFailed;

      // Error message is already displayed in the banner below Query Preview
      // No need for redundant toast notification
    }
  }

  // Process test query results for display
  processTestQueryResults(result) {
    this.recordCount = result.recordCount || 0;

    // Always build columns (even with 0 records)
    const fields =
      result.fields ||
      (result.records && result.records.length > 0
        ? Object.keys(result.records[0])
        : []);

    if (fields.length > 0) {
      this.columns = fields.map((field) => ({
        label: formatLabel(field),
        fieldName: field,
        type: getFieldType(field)
      }));
    }

    if (this.recordCount > 0 && result.records && result.records.length > 0) {
      // ✅ Pass records as-is to preserve child relationships (same as processQueryResults)
      // This ensures that nested relationships (Cases, Contacts, etc.) are preserved
      // and can be displayed with expand/collapse buttons in jtQueryResults component
      this.queryResults = result.records;

      this.hasResults = true;
      this.showTestResults = true;
      this.resetPagination(); // Initialize pagination
    } else {
      // Show empty table with columns
      this.queryResults = [];
      this.hasResults = true; // Show table even with 0 results
      this.showTestResults = true; // Show section
      this.resetPagination();
    }
  }

  // Show create configuration modal
  handleShowCreateModal() {
    this.configModalMode = "create";
    this.showCreateModal = true;
    this.resetNewConfig();
  }

  // Show edit configuration modal
  handleShowEditModal() {
    // Validate and find configuration
    const validation = validateAndFindConfig(
      this.selectedConfig,
      this.configurationOptions,
      this.labels,
      "pleaseSelectConfigurationToEdit"
    );

    if (!validation.isValid) {
      showErrorToast(
        this,
        this.labels.noConfigurationSelected,
        validation.errorMessage
      );
      return;
    }

    const currentConfig = validation.config;

    // Prepare config data
    this.newConfig = {
      label: currentConfig.label,
      developerName: currentConfig.value,
      baseQuery: currentConfig.baseQuery,
      bindings: currentConfig.bindings,
      objectName: currentConfig.objectName
    };

    this.originalDevName = currentConfig.value; // Save original dev name for update
    this.developerNameManuallyEdited = true; // Prevent auto-generation in edit mode

    // Initialize queryValidation for existing query (assume valid)
    this.queryValidation = {
      isValid: true,
      message: this.labels.validSoqlSyntax,
      objectName: currentConfig.objectName || ""
    };

    // Set modal mode and show it
    this.configModalMode = "edit";
    this.showCreateModal = true;

    // Wait for modal to render, then set config
    setTimeout(() => {
      const modal = this.refs.configModal;
      if (modal) {
        modal.setConfig(this.newConfig);
      }
    }, 100);
  }

  // Hide create/edit configuration modal
  handleCloseCreateModal() {
    this.showCreateModal = false;
    this.resetNewConfig();
    this.configModalMode = "create";
  }

  // Handle delete configuration
  async handleDeleteConfiguration() {
    // Validate and find configuration
    const validation = validateAndFindConfig(
      this.selectedConfig,
      this.configurationOptions,
      this.labels,
      "pleaseSelectConfigurationToDelete"
    );

    if (!validation.isValid) {
      showErrorToast(
        this,
        this.labels.noConfigurationSelected,
        validation.errorMessage
      );
      return;
    }

    const currentConfig = validation.config;
    // Get developerName from value (value is the DeveloperName in ConfigurationOption)
    const developerNameToDelete = currentConfig.value;

    // Validate developerName exists
    if (!developerNameToDelete) {
      showErrorToast(
        this,
        this.labels.deleteFailed,
        this.labels.developerNameRequired
      );
      return;
    }

    // Show confirmation modal using LightningConfirm
    const confirmed = await LightningConfirm.open({
      message: this.labels.confirmDeleteConfiguration.replace(
        "{0}",
        currentConfig.label || developerNameToDelete
      ),
      variant: "header",
      label: this.labels.confirmDeleteTitle,
      theme: "error"
    });

    // If user cancelled, do nothing
    if (!confirmed) {
      return;
    }

    // Set loading state
    this.isDeletingConfiguration = true;

    // Call delete method
    deleteConfiguration({ developerName: developerNameToDelete })
      .then((result) => {
        if (result.success) {
          // Metadata API deployment is asynchronous - check if we have a deploymentId
          if (result.deploymentId) {
            // Start polling for deployment status
            showInfoToast(
              this,
              this.labels.deploymentStarted,
              this.labels.deploymentDeletionInProgress
            );
            this.startPollingDeploymentStatus(
              result.deploymentId,
              "deleted",
              null,
              developerNameToDelete
            );
          } else {
            // No deploymentId - treat as synchronous success (shouldn't happen with Metadata API)
            this.isDeletingConfiguration = false;
            showSuccessToast(
              this,
              result.message || this.labels.configurationDeleted,
              this.labels.configurationDeletedSuccess
            );

            // Clear selection and preview if the deleted config was selected
            const wasSelected = this.selectedConfig === developerNameToDelete;
            this.selectedConfig = "";

            // Reset the combobox component to clear its internal state
            const combobox = this.template.querySelector(
              'c-jt-searchable-combobox[test-id="config-selector"]'
            );
            if (combobox) {
              combobox.reset();
            }

            // Clear preview data if the deleted config was being displayed
            if (wasSelected) {
              this.baseQuery = "";
              this.bindings = "";
              this.objectName = "";
              this.queryResults = [];
              this.hasResults = false;
              this.queryPreviewData = [];
              this.showPreviewData = false;
              this.recordCount = 0;
              this.previewRecordCount = 0;
            }

            // Refresh the configurations list to update dropdown
            refreshApex(this.wiredConfigurationsResult);
          }
        } else {
          this.isDeletingConfiguration = false;
          showErrorToast(this, this.labels.deleteFailed, result.errorMessage);
        }
        return Promise.resolve();
      })
      .catch((error) => {
        this.isDeletingConfiguration = false; // Hide spinner on error
        showErrorToast(
          this,
          this.labels.errorTitle,
          extractErrorMessage(error, this.labels.failedToDeleteConfiguration)
        );
      });
  }

  // Reset new configuration form
  resetNewConfig() {
    this.newConfig = {
      label: "",
      developerName: "",
      baseQuery: "",
      bindings: "",
      objectName: ""
    };
    this.queryValidation = { isValid: false, message: "" };
    this.developerNameManuallyEdited = false;
    this.queryPreviewResults = [];
    this.queryPreviewColumns = [];
    this.isLoadingQueryPreview = false;
    this.originalDevName = ""; // Reset for edit mode
  }

  // Show usage modal
  handleShowUsageModal(event) {
    // Prevent default anchor behavior to avoid CSP violation
    if (event) {
      event.preventDefault();
    }

    // Validate config is selected
    const selectionValidation = validateConfigSelected(
      this.selectedConfig,
      this.labels,
      "pleaseSelectConfiguration"
    );
    if (!selectionValidation.isValid) {
      showErrorToast(
        this,
        this.labels.noConfigurationSelected,
        selectionValidation.errorMessage
      );
      return;
    }

    // Don't show modal yet - wait until search completes
    this.isLoadingUsage = true;
    this.usageResults = [];
    this.usageServiceErrors = { apex: null, flow: null };
    this.hasPartialUsageResults = false;

    // 🎯 Call with Continuation for API-enabled session
    findAllUsagesWithContinuation({ configName: this.selectedConfig })
      .then((result) => {
        // Parse JSON response from Apex (returned as string to avoid serialization issues)
        const aggregated = JSON.parse(result);

        // Aggregate all successful results
        this.usageResults = aggregated.allResults || [];
        this.hasPartialUsageResults = aggregated.hasPartialResults;

        // Track service errors (for display in modal, no toast)
        if (!aggregated.apexService.success) {
          this.usageServiceErrors.apex = aggregated.apexService.error;
        }

        if (!aggregated.flowService.success) {
          this.usageServiceErrors.flow = aggregated.flowService.error;
        }

        // Now show modal with results
        this.isLoadingUsage = false;
        this.showUsageModal = true;

        // Show single warning only if there are partial results
        if (this.hasPartialUsageResults && this.usageResults.length > 0) {
          showWarningToast(
            this,
            this.labels.partialResults,
            this.labels.partialResultsMessage.replace(
              "{0}",
              this.usageResults.length
            )
          );
        }

        // Log the usage search for audit purposes
        logUsageSearch({
          configName: this.selectedConfig,
          resultCount: this.usageResults.length
        }).catch(() => {
          // Don't fail if logging fails - silent error
        });
      })
      .catch((error) => {
        showErrorToast(
          this,
          this.labels.searchError,
          extractErrorMessage(
            error,
            this.labels.failedToExecuteSearchOrchestrator
          )
        );
        this.isLoadingUsage = false;
        // Don't show modal on error - user can try again
      });
  }

  // Close usage modal
  handleCloseUsageModal() {
    this.showUsageModal = false;
    this.usageResults = [];
  }

  // ============================================
  // Cache Management
  // ============================================
  handleOpenCacheModal() {
    this.showCacheModal = true;
    // Call open() on the modal after it renders
    requestAnimationFrame(() => {
      const modal = this.refs.cacheModal;
      if (modal) {
        modal.open();
      }
    });
  }

  handleCloseCacheModal() {
    // Close the modal child component first
    const modal = this.refs.cacheModal;
    if (modal) {
      modal.close();
    }
    // Then hide it from parent
    this.showCacheModal = false;
  }

  async handleClearCache(event) {
    const { configurations, results, users, recent } = event.detail;
    const cleared = [];

    try {
      // Clear server-side platform cache first so client-side "refreshApex" reflects it.
      // Only configurations are stored in the dedicated partition in this project.
      await clearPlatformCache({
        configurations: configurations ?? false,
        results: results ?? false,
        users: users ?? false,
        recent: recent ?? false
      });

      // Clear configurations
      if (configurations) {
        await refreshApex(this.wiredConfigurationsResult);
        cleared.push(this.labels.clearConfigurationsLabel);
      }

      // Clear results
      if (results) {
        this.queryResults = [];
        this.hasResults = false;
        this.recordCount = 0;
        this.currentPage = 1;
        this.jsonOutput = "";
        cleared.push(this.labels.clearResultsLabel);
      }

      // Clear users
      if (users) {
        this.userOptions = [];
        this.loadAllUsers(); // Reload all users
        cleared.push(this.labels.clearUsersLabel);
      }

      // Clear recent selections
      if (recent) {
        this.selectedConfig = "";
        this.baseQuery = "";
        this.parameters = [];
        this.parameterValues = {};
        this.runAsUserId = "";
        this.runAsUserName = "";
        cleared.push(this.labels.clearRecentLabel);
      }

      // Show success toast
      if (cleared.length > 0) {
        const message = `${this.labels.cacheCleared}: ${this.labels.cacheClearedDetail.replace("{0}", cleared.join(", "))}`;
        showSuccessToast(this, message);
      }

      // Close modal after clearing
      this.handleCloseCacheModal();
    } catch (error) {
      const errorMsg =
        error.body?.message || error.message || this.labels.unknownError;
      showErrorToast(
        this,
        this.labels.errorTitle,
        this.labels.errorClearingCache.replace("{0}", errorMsg)
      );
    }
  }

  get hasUsageResults() {
    return this.usageResults && this.usageResults.length > 0;
  }

  get selectedConfigEmpty() {
    return !this.selectedConfig;
  }

  get usageColumns() {
    return [
      {
        label: "Name",
        fieldName: "className",
        type: "text",
        wrapText: false
      },
      {
        label: "Type",
        fieldName: "metadataType",
        type: "text",
        initialWidth: 120
      },
      {
        label: "Line #",
        fieldName: "lineNumber",
        type: "number",
        initialWidth: 80
      },
      { label: "Code", fieldName: "codeLine", type: "text", wrapText: true }
    ];
  }

  // Handle new config input changes
  handleNewConfigChange(event) {
    const field = event.target.dataset.field;
    this.newConfig[field] = event.target.value;

    // Track if developer name was manually edited
    if (field === "developerName") {
      this.developerNameManuallyEdited = true;
    }

    // Auto-generate developer name from label (only if not manually edited)
    if (field === "label" && !this.developerNameManuallyEdited) {
      this.newConfig.developerName = event.target.value
        .replace(/[^a-zA-Z0-9]/g, "_")
        .replace(/^([^a-zA-Z])/, "Config_$1")
        .substring(0, 40); // Salesforce API name limit
    }

    // Note: Query validation now handled directly by jtConfigModal component
  }

  // Handle query preview event from modal (Modal now handles validation & preview)
  handleQueryPreview(event) {
    const { records, fields } = event.detail;

    this.queryPreviewResults = records || [];

    if (fields && fields.length > 0) {
      this.queryPreviewColumns = fields.map((field) => ({
        label: formatLabel(field),
        fieldName: field,
        type: getFieldType(field)
      }));
    } else {
      this.queryPreviewColumns = [];
    }
  }

  // Save configuration (create or update)
  handleSaveConfiguration(event) {
    // Get config from modal if available
    const modal = this.refs.configModal;
    let configFromModal = null;
    let modalQueryValidation = null;
    if (modal) {
      configFromModal = modal.getConfig();
      // Get query validation state from modal (it handles its own validation)
      modalQueryValidation = modal.getQueryValidation();
    }

    // Use config from event detail if available, otherwise use newConfig
    const configToUse =
      event?.detail?.config || configFromModal || this.newConfig;

    // Validate configToUse exists
    const configExistsValidation = validateConfigExists(configToUse);
    if (!configExistsValidation.isValid) {
      showErrorToast(
        this,
        "Configuration Error",
        configExistsValidation.errorMessage
      );
      return;
    }

    // Validate required fields
    const requiredFieldsValidation = validateRequiredFields(configToUse);
    if (!requiredFieldsValidation.isValid) {
      showErrorToast(
        this,
        "Validation Error",
        requiredFieldsValidation.errorMessage
      );
      return;
    }

    const queryValidationToCheck = modalQueryValidation || this.queryValidation;

    if (!queryValidationToCheck || !queryValidationToCheck.isValid) {
      if (!configToUse.baseQuery || configToUse.baseQuery.trim().length === 0) {
        showErrorToast(
          this,
          this.labels.invalidQuery,
          "Query is required. Please enter a valid SOQL query."
        );
        return;
      }
    }

    this.isSaving = true;

    // Sanitize configuration data
    const configData = sanitizeConfigData(configToUse);

    // Double-check required fields after sanitization
    const sanitizedValidation = validateRequiredFields(configData);
    if (!sanitizedValidation.isValid) {
      showErrorToast(
        this,
        "Validation Error",
        sanitizedValidation.errorMessage + " Please check your input."
      );
      this.isSaving = false;
      return;
    }

    // Choose create or update based on mode
    const modeFromEvent = event?.detail?.mode || this.configModalMode;

    // Validate edit mode requirements
    const editModeValidation = validateEditMode(
      modeFromEvent,
      this.originalDevName
    );
    if (!editModeValidation.isValid) {
      showErrorToast(
        this,
        "Configuration Error",
        editModeValidation.errorMessage
      );
      this.isSaving = false;
      return;
    }

    // Serialize configData to JSON string for Apex deserialization
    // For edit mode, include originalDevName
    let configDataForApex;
    if (modeFromEvent === "edit") {
      // Exclude originalDevName from configData if it exists, then set it explicitly
      // eslint-disable-next-line no-unused-vars
      const { originalDevName, ...configDataWithoutOriginal } = configData;
      configDataForApex = {
        ...configDataWithoutOriginal,
        originalDevName: this.originalDevName || configData.developerName
      };
    } else {
      configDataForApex = configData;
    }

    // Ensure configDataForApex is a plain object (not already a string)
    if (typeof configDataForApex === "string") {
      showErrorToast(
        this,
        "Configuration Error",
        "Invalid configuration data format. Please try again."
      );
      this.isSaving = false;
      return;
    }

    // Validate that configDataForApex is an object
    if (
      !configDataForApex ||
      typeof configDataForApex !== "object" ||
      Array.isArray(configDataForApex)
    ) {
      showErrorToast(
        this,
        "Configuration Error",
        "Configuration data must be a valid object. Please check your input."
      );
      this.isSaving = false;
      return;
    }

    // Serialize to JSON string - ensure it's a single string, not double-encoded
    let configJson;
    try {
      configJson = JSON.stringify(configDataForApex);
      // Validate that the result is a string
      if (typeof configJson !== "string") {
        throw new Error("JSON.stringify did not return a string");
      }
    } catch (jsonError) {
      showErrorToast(
        this,
        "Configuration Error",
        `Failed to serialize configuration: ${jsonError.message}`
      );
      this.isSaving = false;
      return;
    }

    const saveMethod =
      modeFromEvent === "edit"
        ? updateConfiguration({ configJson })
        : createConfiguration({ configJson });

    const actionLabel = modeFromEvent === "edit" ? "Updated" : "Created";

    // Store config data for potential update of selected config
    const updatedConfigData = configData;
    const updatedDevName = configData.developerName || this.originalDevName;

    saveMethod
      .then((result) => {
        if (result.success) {
          // Check if deployment is asynchronous (has deploymentId)
          if (result.deploymentId) {
            // Deployment is asynchronous - poll for status
            // Show info toast immediately to give user feedback
            showInfoToast(
              this,
              this.labels.deploymentInProgress,
              this.labels.deploymentInitiated.replace("{0}", actionLabel)
            );

            // Don't reset originalDevName yet - keep it for potential retry
            this.showCreateModal = false;
            this.configModalMode = "create";
            this.resetNewConfig();
            this.startPollingDeploymentStatus(
              result.deploymentId,
              actionLabel,
              updatedConfigData,
              updatedDevName
            );
            return Promise.resolve();
          }

          // Deployment is synchronous (update) - refresh immediately
          showSuccessToast(
            this,
            result.message ||
              this.labels.configurationActionSuccessfully.replace(
                "{0}",
                actionLabel
              ),
            this.labels.configurationActionSuccessfully.replace(
              "{0}",
              actionLabel
            )
          );

          // Update selected config if it matches the updated one
          this.updateSelectedConfigIfMatches(updatedDevName, updatedConfigData);

          this.handleCloseCreateModal();

          // Refresh the configurations list using refreshApex
          // Note: Since getConfigurations is cacheable, we may need to wait a bit
          // for metadata changes to propagate, then refresh
          return this.refreshConfigurationsWithRetry(
            updatedDevName,
            updatedConfigData
          );
        }
        // Show error toast and don't refresh
        showErrorToast(
          this,
          `${actionLabel} Failed`,
          result.errorMessage || this.labels.unknownError
        );
        return Promise.resolve();
      })
      .catch((error) => {
        showErrorToast(
          this,
          this.labels.errorTitle,
          extractErrorMessage(
            error,
            `Failed to ${this.configModalMode} configuration`
          )
        );
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  // Start polling for deployment status
  startPollingDeploymentStatus(
    deploymentId,
    actionLabel,
    updatedConfigData = null,
    updatedDevName = null
  ) {
    const stopPolling = pollUntilComplete(
      // Poll function
      () => {
        return checkDeploymentStatus({ deploymentId });
      },
      // Check if complete
      (result) => {
        if (!result) {
          return false;
        }

        // Check done flag (handle both boolean true and string "true")
        const done =
          result.done === true ||
          result.done === "true" ||
          result.rawDone === true;

        // Check status field as fallback
        const statusValue = result.status;
        const isStatusComplete =
          statusValue &&
          (statusValue === "Succeeded" ||
            statusValue === "Failed" ||
            statusValue === "Canceled" ||
            statusValue === "ERROR");

        // Deployment is complete if done is true OR status indicates completion
        const isComplete = done || isStatusComplete;
        return isComplete;
      },
      // On complete
      (result) => {
        // Hide spinner for deletion (create/update use isSaving)
        if (actionLabel === "deleted") {
          this.isDeletingConfiguration = false;
        }

        if (result.success === true) {
          // Deployment succeeded - show success toast and refresh list
          showSuccessToast(
            this,
            this.labels.configurationActionSuccessfully.replace(
              "{0}",
              actionLabel
            ),
            this.labels.metadataDeploymentCompleted
          );

          // Handle deletion: clear preview if deleted config was selected
          if (actionLabel === "deleted" && updatedDevName) {
            const wasSelected = this.selectedConfig === updatedDevName;
            if (wasSelected) {
              this.selectedConfig = "";

              // Reset the combobox component to clear its internal state
              const combobox = this.template.querySelector(
                'c-jt-searchable-combobox[test-id="config-selector"]'
              );
              if (combobox) {
                combobox.reset();
              }

              // Clear preview data
              this.baseQuery = "";
              this.bindings = "";
              this.objectName = "";
              this.queryResults = [];
              this.hasResults = false;
              this.queryPreviewData = [];
              this.showPreviewData = false;
              this.recordCount = 0;
              this.previewRecordCount = 0;
            }
          } else if (updatedConfigData && updatedDevName) {
            // Update selected config if it matches the updated one (for create/update)
            this.updateSelectedConfigIfMatches(
              updatedDevName,
              updatedConfigData
            );
          }

          // Refresh the configurations list using refreshApex with retry logic
          // Use longer delays for async deployments (metadata takes longer to propagate)
          // Don't show toast here since we already showed the success toast above
          this.refreshConfigurationsWithRetry(
            updatedDevName,
            updatedConfigData,
            4,
            1000,
            false
          );
        } else {
          // Deployment failed - show error toast
          const errorMsg =
            result.error || this.labels.deploymentFailedCheckStatus;
          showErrorToast(
            this,
            this.labels.actionFailed.replace("{0}", actionLabel),
            errorMsg
          );
        }
      },
      // On error
      (error) => {
        // Hide spinner for deletion on error
        if (actionLabel === "deleted") {
          this.isDeletingConfiguration = false;
        }
        showErrorToast(
          this,
          this.labels.deploymentStatusCheckFailed,
          extractErrorMessage(error, this.labels.failedToCheckDeploymentStatus)
        );
      },
      // On timeout
      () => {
        // Hide spinner for deletion on timeout
        if (actionLabel === "deleted") {
          this.isDeletingConfiguration = false;
        }
        showErrorToast(
          this,
          this.labels.deploymentTimeout,
          this.labels.deploymentTimeoutMessage.replace("{0}", deploymentId)
        );
      },
      // Options - optimized for metadata deployments
      {
        interval: 1000, // Start with 1 second intervals
        maxPolls: 60, // Allow up to 60 polls (with exponential backoff, this gives ~2-3 minutes max)
        immediateFirstPoll: true, // Poll immediately without waiting
        exponentialBackoff: true, // Gradually increase interval if taking longer
        maxInterval: 3000 // Max 3 seconds between polls
      }
    );

    // Store stop function for cleanup
    this.deploymentPollInterval = stopPolling;
  }

  // Update selected configuration data if it matches the updated one
  updateSelectedConfigIfMatches(updatedDevName, updatedConfigData) {
    if (!updatedDevName || !updatedConfigData) return;

    // Check if the updated config is currently selected
    if (this.selectedConfig === updatedDevName) {
      // Update baseQuery and bindings if they changed
      if (updatedConfigData.baseQuery) {
        this.baseQuery = updatedConfigData.baseQuery;
      }
      if (updatedConfigData.bindings !== undefined) {
        this.bindings = updatedConfigData.bindings || "";
      }
      if (updatedConfigData.objectName) {
        this.objectName = updatedConfigData.objectName;
      }

      // Re-extract parameters if bindings are not predefined
      if (!this.hasBindings) {
        this.extractQueryParameters();
      } else {
        // Clear parameters if bindings are predefined
        this.parameters = [];
        this.parameterValues = {};
      }

      // If modal is open and showing preview, trigger preview update
      const modal = this.refs.configModal;
      if (modal && this.showCreateModal) {
        // Modal will handle its own preview update when config changes
        // We can trigger a config change event if needed
      }
    }
  }

  /**
   * @description Refreshes configurations list with retry logic to handle cache propagation delays
   * @param {string} devName - Developer name of the updated configuration
   * @param {object} expectedData - Expected configuration data
   * @param {number} maxRetries - Maximum number of retry attempts (default: 3)
   * @param {number} initialDelay - Initial delay in ms before first refresh (default: 500)
   * @returns {Promise} Resolves when refresh is successful or max retries reached
   */
  refreshConfigurationsWithRetry(
    devName,
    expectedData,
    maxRetries = 3,
    initialDelay = 500,
    showToast = true
  ) {
    return new Promise((resolve) => {
      let attempt = 0;

      const attemptRefresh = () => {
        attempt++;
        const delay = initialDelay * attempt; // Exponential backoff: 500ms, 1000ms, 1500ms

        setTimeout(() => {
          refreshApex(this.wiredConfigurationsResult)
            .then(() => {
              // Wait a bit for wire to update after refreshApex completes
              return new Promise((innerResolve) => {
                setTimeout(() => {
                  innerResolve();
                }, 300);
              });
            })
            .then(() => {
              // Validate that the update was reflected
              return this.validateConfigurationUpdate(devName, expectedData);
            })
            .then((isValid) => {
              if (isValid) {
                if (showToast) {
                  showInfoToast(
                    this,
                    this.labels.listUpdated,
                    this.labels.configurationListRefreshed
                  );
                }
                resolve();
              } else if (attempt < maxRetries) {
                console.warn(
                  `⚠️ Configuration update not visible yet, retrying in ${delay}ms...`
                );
                attemptRefresh();
              } else {
                console.warn(
                  `⚠️ Configuration update not visible after ${maxRetries} attempts. Showing success message anyway.`
                );
                // Show success message even if validation failed - the update likely succeeded server-side
                if (showToast) {
                  showInfoToast(
                    this,
                    this.labels.listUpdated,
                    this.labels.configurationListRefreshed +
                      " (Please refresh the page if changes are not visible)"
                  );
                }
                resolve();
              }
            })
            .catch((error) => {
              console.error("❌ Error during configuration refresh:", error);
              if (attempt < maxRetries) {
                attemptRefresh();
              } else {
                if (showToast) {
                  showInfoToast(
                    this,
                    this.labels.listUpdated,
                    this.labels.configurationListRefreshed
                  );
                }
                resolve();
              }
            });
        }, delay);
      };

      // Start first attempt immediately
      attemptRefresh();
    });
  }

  /**
   * @description Validates that a configuration update was reflected in the UI
   * @param {string} devName - Developer name of the updated configuration
   * @param {object} expectedData - Expected configuration data (baseQuery, bindings, etc.)
   * @returns {Promise<boolean>} True if validation passes, false otherwise
   */
  validateConfigurationUpdate(devName, expectedData) {
    return new Promise((resolve) => {
      // Wait a bit for the wire to update
      setTimeout(() => {
        // Check wire status
        if (this.wiredConfigurationsResult?.error) {
          console.error("❌ Wire error:", this.wiredConfigurationsResult.error);
          resolve(false);
          return;
        }

        if (
          !this.configurationOptions ||
          this.configurationOptions.length === 0
        ) {
          resolve(false);
          return;
        }

        // Find the updated configuration in the list
        const updatedConfig = this.configurationOptions.find(
          (config) => config.value === devName
        );

        if (!updatedConfig) {
          console.warn(
            `⚠️ Updated configuration "${devName}" not found in list`
          );
          resolve(false);
          return;
        }

        // Validate that the data matches what we expect
        let isValid = true;
        const mismatches = [];

        if (
          expectedData.baseQuery &&
          updatedConfig.baseQuery !== expectedData.baseQuery
        ) {
          isValid = false;
          mismatches.push("baseQuery");
        }

        // Normalize bindings: treat undefined, null, and empty string as equivalent
        const normalizeBindings = (value) => {
          if (value === undefined || value === null || value === "") {
            return "";
          }
          return value;
        };

        const expectedBindings = normalizeBindings(expectedData.bindings);
        const actualBindings = normalizeBindings(updatedConfig.bindings);

        if (expectedBindings !== actualBindings) {
          isValid = false;
          mismatches.push("bindings");
        }

        if (
          expectedData.objectName &&
          updatedConfig.objectName !== expectedData.objectName
        ) {
          isValid = false;
          mismatches.push("objectName");
        }

        if (isValid) {
          // Configuration validated successfully
        } else {
          console.warn(
            `⚠️ Configuration "${devName}" update validation failed. Mismatches: ${mismatches.join(", ")}`
          );
        }

        resolve(isValid);
      }, 500); // Wait 500ms for wire to update
    });
  }

  // Disconnect polling on component destroy
  connectedCallback() {
    this.loadUsageTrackingSetting();

    // Safety timeout: hide spinner after 10 seconds even if wire methods haven't completed
    // This prevents the UI from being blocked indefinitely
    setTimeout(() => {
      if (this.isInitialLoading) {
        this.isInitialLoading = false;
      }
    }, 10000);
  }

  disconnectedCallback() {
    if (this.pollInterval) {
      // pollInterval is now a function (stopPolling), not an interval ID
      if (typeof this.pollInterval === "function") {
        this.pollInterval();
      } else {
        // Fallback for old interval ID format (shouldn't happen, but safe)
        clearInterval(this.pollInterval);
      }
      this.pollInterval = null;
    }
    if (this.deploymentPollInterval) {
      // deploymentPollInterval is a function (stopPolling)
      if (typeof this.deploymentPollInterval === "function") {
        this.deploymentPollInterval();
      }
      this.deploymentPollInterval = null;
    }
  }

  /**
   * @description Error boundary - Handles errors from child components
   * @param {Error} error - The error object
   * @param {String} stack - The error stack trace (unused in production)
   */
  errorCallback(error) {
    // Show user-friendly error without breaking the entire UI
    showWarningToast(
      this,
      "Component Error",
      `A component encountered an error: ${error.message}. Other features remain functional.`
    );
  }

  // Load usage tracking setting
  async loadUsageTrackingSetting() {
    try {
      this.usageTrackingEnabled = await getUsageTrackingSetting();
    } catch {
      this.usageTrackingEnabled = false;
    }
  }

  // Handle usage tracking toggle
  async handleUsageTrackingChange(event) {
    const enabled = event.target.checked;
    this.isUpdatingSettings = true;

    try {
      const success = await updateUsageTrackingSetting({ enabled });
      if (success) {
        this.usageTrackingEnabled = enabled;
        showSuccessToast(
          this,
          enabled ? "Usage tracking enabled" : "Usage tracking disabled"
        );
      }
    } catch (error) {
      showErrorToast(
        this,
        "Update Failed",
        error.body?.message || "Failed to update usage tracking setting"
      );
      // Revert checkbox
      event.target.checked = !enabled;
    } finally {
      this.isUpdatingSettings = false;
    }
  }

  // Computed property for showing usage link
  get showUsageLink() {
    return this.selectedConfig && this.usageTrackingEnabled;
  }

  // Computed property for showing edit button
  get showEditConfigButton() {
    return this.canCreateMetadata && this.selectedConfig;
  }

  // Computed property for showing delete button
  get showDeleteConfigButton() {
    return this.canCreateMetadata && this.selectedConfig;
  }

  // Navigate to Documentation tab
  handleGoToDocumentation(event) {
    event.preventDefault();
    // Navigate to Documentation tab in the app
    // This will use the NavigationMixin in a future enhancement
    // For now, show a toast with instructions
    showInfoToast(
      this,
      "Tooling API Setup",
      this.labels.toolingApiSetupInstructions
    );
  }

  // Execute the query (entry point with risk assessment)
  handleExecuteQuery() {
    // Prevent execution if Run As User test is in progress
    if (this.isRunningTest) {
      showErrorToast(
        this,
        "Test Execution in Progress",
        "Please wait for the current Run As User test execution to complete."
      );
      return;
    }

    // ✅ FIX: Disable button IMMEDIATELY to prevent multiple clicks
    this.isLoading = true;

    // Validate config is selected
    const selectionValidation = validateConfigSelected(
      this.selectedConfig,
      this.labels,
      "pleaseSelectConfiguration"
    );
    if (!selectionValidation.isValid) {
      this.isLoading = false; // Re-enable if validation fails
      showErrorToast(
        this,
        this.labels.configurationRequired,
        selectionValidation.errorMessage
      );
      return;
    }

    // 🎯 SMART ROUTING: If runAsUserId is selected, use System.runAs() flow
    if (this.runAsUserId) {
      this.isLoading = false; // 🐛 FIX: Reset spinner - handleExecuteAsUserTest uses its own spinner (isRunningTest)
      this.handleExecuteAsUserTest(); // Use test class with System.runAs()
      return;
    }

    // 🎯 SMART ROUTING: If persona mode is active with a selection, use persona flow
    if (this.runAsPersonaDevName) {
      this.isLoading = false;
      this.handleExecuteAsPersonaTest();
      return;
    }

    // 🚨 RISK ASSESSMENT: Check if query is dangerous before executing
    this.assessQueryRiskAndExecute();
  }

  // Assess query risk and show warning if necessary
  assessQueryRiskAndExecute() {
    this.isAssessingRisk = true;
    // Note: isLoading already set to true in handleExecuteQuery

    // Build bindings JSON (same logic as before)
    const bindingsToSend = this.buildBindingsJson();

    assessQueryRisk({
      devName: this.selectedConfig,
      bindingsJson: bindingsToSend
    })
      .then((assessment) => {
        this.queryRiskAssessment = assessment;

        // If critical risk (>50K) → MUST use batch processing
        if (assessment.isCriticalRisk) {
          this.showRiskWarningModal = true;
          this.pendingExecutionMode = "batch"; // Force batch mode
        }
        // If high risk (>10K) → Recommend batch processing
        else if (assessment.isHighRisk || assessment.recommendBatchProcessing) {
          this.showRiskWarningModal = true;
          this.pendingExecutionMode = "batch"; // Suggest batch mode
        }
        // Low risk → Execute normally
        else {
          this.executeQueryNormal();
        }
      })
      .catch((error) => {
        // Fail closed: a risk assessment failure is itself evidence the query may be
        // expensive/unselective, so it must never silently fall through to an unbounded
        // executeQueryNormal(). Surface a blocking error instead.
        this.isLoading = false;
        this.showError = true;
        this.errorMessage = error.body?.message || this.labels.unknownError;
        showErrorToast(
          this,
          this.labels.riskAssessmentFailed,
          this.errorMessage
        );
      })
      .finally(() => {
        this.isAssessingRisk = false;
      });
  }

  // Execute query normally (without batch processing)
  executeQueryNormal() {
    // Note: isLoading already set to true in handleExecuteQuery
    this.showError = false;
    this.resetResults();

    const bindingsToSend = this.buildBindingsJson();

    executeQuery({
      devName: this.selectedConfig,
      bindingsJson: bindingsToSend,
      runAsUserId: this.runAsUserId || null
    })
      .then((result) => {
        if (result.success) {
          this.processQueryResults(result);
          // Success toast removed - results are already displayed in the table
          // Use setTimeout to ensure LWC reactivity processes the state changes
          // This forces a re-render cycle after data is set
          setTimeout(() => {
            // CRITICAL: Set isLoading to false AFTER processQueryResults
            // This ensures showResults getter returns true
            this.isLoading = false;
          }, 0);
        } else {
          this.showError = true;
          this.errorMessage = result.errorMessage;
          showErrorToast(this, this.labels.queryError, result.errorMessage);
          this.isLoading = false;
        }
      })
      .catch((error) => {
        this.showError = true;
        this.errorMessage = error.body?.message || this.labels.unknownError;
        showErrorToast(this, this.labels.executionError, this.errorMessage);
        this.isLoading = false;
      });
  }

  // Execute query with batch processing (for large result sets)
  executeQueryWithBatches() {
    // Note: isLoading already set to true in handleExecuteQuery
    this.showError = false;
    this.resetResults();

    const bindingsToSend = this.buildBindingsJson();

    executeQueryWithBatchProcessing({
      devName: this.selectedConfig,
      bindingsJson: bindingsToSend,
      batchSize: 200 // Process 200 records at a time
    })
      .then((result) => {
        if (result.success) {
          this.processQueryResults(result);
          // Use setTimeout to ensure LWC reactivity processes the state changes
          // This forces a re-render cycle after data is set
          setTimeout(() => {
            // CRITICAL: Set isLoading to false AFTER processQueryResults
            // This ensures showResults getter returns true
            this.isLoading = false;
          }, 0);
        } else {
          this.showError = true;
          this.errorMessage = result.errorMessage;
          showErrorToast(this, this.labels.queryError, result.errorMessage);
          this.isLoading = false;
        }
      })
      .catch((error) => {
        this.showError = true;
        this.errorMessage = error.body?.message || this.labels.unknownError;
        showErrorToast(this, this.labels.executionError, this.errorMessage);
        this.isLoading = false;
      });
  }

  // Handle risk warning modal actions
  handleProceedWithBatch() {
    this.showRiskWarningModal = false;
    this.executeQueryWithBatches();
  }

  handleProceedNormal() {
    this.showRiskWarningModal = false;
    this.executeQueryNormal();
  }

  handleCancelExecution() {
    this.showRiskWarningModal = false;
    this.isLoading = false;
    showInfoToast(
      this,
      "Execution Cancelled",
      "Query execution was cancelled."
    );
  }

  // Process query results for datatable
  processQueryResults(result) {
    this.recordCount = result.recordCount;

    // Always build columns (even with 0 records)
    if (result.fields && result.fields.length > 0) {
      this.columns = result.fields.map((field) => ({
        label: formatLabel(field),
        fieldName: field,
        type: getFieldType(field)
      }));
    }

    if (result.recordCount > 0) {
      // ✅ Pass records as-is to preserve child relationships
      this.queryResults = result.records;

      this.hasResults = true;
      this.resetPagination(); // Initialize pagination
      // Success toast removed - results are already displayed in the table
    } else {
      // Show empty table with columns
      this.queryResults = [];
      this.hasResults = true; // Changed: show table even with 0 results
      this.resetPagination();
      showInfoToast(this, "No Results", "Query returned no records.");
    }
  }

  // Reset results
  resetResults() {
    this.queryResults = [];
    this.columns = [];
    this.recordCount = 0;
    this.hasResults = false;
    this.showError = false;
    this.errorMessage = "";
    this.expandedCards.clear();
    this.viewMode = { table: true, json: false, csv: false };
  }

  // Handle view mode change (Table/JSON/CSV)
  handleViewChange(event) {
    const view = event.currentTarget.dataset.view;
    this.viewMode = {
      table: view === "table",
      json: view === "json",
      csv: view === "csv"
    };

    if (view === "json") {
      this.generateJsonOutput();
    } else if (view === "csv") {
      // CSV view is just a download prompt, no generation here
      this.jsonOutput = "";
    }
  }

  // Handle card expand/collapse toggle
  handleCardToggle(event) {
    const recordId = event.currentTarget.dataset.id;
    if (this.expandedCards.has(recordId)) {
      this.expandedCards.delete(recordId);
    } else {
      this.expandedCards.add(recordId);
    }
    // Force re-render of paginated results
    this.queryResults = [...this.queryResults];
  }

  // Generate JSON output
  generateJsonOutput() {
    try {
      const output = {
        metadata: {
          totalRecords: this.recordCount,
          fields: this.columns.map((col) => col.fieldName),
          objectType: this.objectName || "Unknown",
          exportDate: new Date().toISOString()
        },
        records: this.queryResults
      };
      this.jsonOutput = JSON.stringify(output, null, 2);
    } catch {
      showErrorToast(this, "JSON Error", "Failed to generate JSON output");
      this.jsonOutput = "{}";
    }
  }

  // Copy JSON to clipboard
  handleCopyJson() {
    if (navigator.clipboard && this.jsonOutput) {
      navigator.clipboard
        .writeText(this.jsonOutput)
        .then(() => {
          showSuccessToast(this, "JSON copied to clipboard");
        })
        .catch(() => {
          showErrorToast(
            this,
            "Copy Failed",
            "Could not copy JSON to clipboard"
          );
        });
    }
  }

  // Download CSV
  handleDownloadCsv() {
    try {
      if (!this.queryResults || this.queryResults.length === 0) {
        showErrorToast(this, "No Data", "No records to export");
        return;
      }

      // Generate CSV content
      const headers = this.columns.map((col) => col.label).join(",");
      const rows = this.queryResults.map((row) => {
        return this.columns
          .map((col) => {
            const value = row[col.fieldName] || "";
            // Escape commas and quotes in CSV
            const escaped = String(value).replace(/"/g, '""');
            return `"${escaped}"`;
          })
          .join(",");
      });
      const csvContent = [headers, ...rows].join("\n");

      // Create and download file
      const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
      const link = document.createElement("a");
      const url = URL.createObjectURL(blob);
      link.setAttribute("href", url);
      link.setAttribute(
        "download",
        `query_results_${new Date().getTime()}.csv`
      );
      link.style.visibility = "hidden";
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      showSuccessToast(this, "CSV downloaded successfully");
    } catch {
      showErrorToast(this, "CSV Error", "Failed to generate CSV file");
    }
  }
}
