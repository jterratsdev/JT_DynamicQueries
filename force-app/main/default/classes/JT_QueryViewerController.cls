/**
 * @description Controller for the Query Viewer LWC
 * @author Jaime Terrats
 * @group Dynamic Queries
 * @last modified on 12-11-2025
 * @last modified by Jaime Terrats
 *
 * PMD Suppressions:
 * - CognitiveComplexity/CyclomaticComplexity: Controller orchestrates complex query operations
 * - AvoidDeeplyNestedIfStmts: Necessary for bind variable processing and risk assessment
 **/
@SuppressWarnings(
  'PMD.CognitiveComplexity, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.AvoidDeeplyNestedIfStmts, PMD.ApexDoc'
)
public with sharing class JT_QueryViewerController {
  /**
   * @description Clears Platform Cache entries used by this package for the Query Viewer.
   * Currently it targets the dedicated partition used by `JT_DataSelector` for configuration metadata.
   */
  @AuraEnabled
  public static void clearPlatformCache(
    Boolean configurations,
    Boolean results,
    Boolean users,
    Boolean recent
  ) {
    // The dedicated partition in this project currently holds only configuration metadata cache.
    if (configurations == null || !configurations) {
      return;
    }

    // Keep the key format in sync with `JT_DataSelector.getConfig()`
    final String partitionName = 'local.JTDynamicQueries';
    Cache.OrgPartition part = Cache.Org.getPartition(partitionName);

    // Admin tool: at most 200 metadata configs.
    List<JT_DynamicQueryConfiguration__mdt> configs = [
      SELECT DeveloperName
      FROM JT_DynamicQueryConfiguration__mdt
      WITH USER_MODE
      ORDER BY Label ASC
      LIMIT 200
    ];

    for (JT_DynamicQueryConfiguration__mdt c : configs) {
      String sanitizedDevName = JT_ToolingApiUtil.toAlphanumeric(
        c.DeveloperName
      );
      if (String.isNotBlank(sanitizedDevName)) {
        part.remove('Config' + sanitizedDevName);
      }
    }
  }

  /**
   * @description Retrieves all available query configurations
   * @author Jaime Terrats | 11-28-2025
   * @return List<ConfigurationOption>
   **/
  @AuraEnabled(cacheable=true)
  public static List<ConfigurationOption> getConfigurations() {
    try {
      // ✅ REFACTORED: Use Selector Layer (2025-12-02)
      List<JT_DynamicQueryConfiguration__mdt> configs = JT_ConfigurationSelector.getConfigurations();

      List<ConfigurationOption> options = new List<ConfigurationOption>();
      for (JT_DynamicQueryConfiguration__mdt config : configs) {
        ConfigurationOption opt = new ConfigurationOption();
        opt.label = config.Label;
        opt.value = config.DeveloperName;
        opt.baseQuery = config.JT_BaseQuery__c;
        opt.bindings = config.JT_Binding__c;
        opt.objectName = config.JT_ObjectName__c;
        options.add(opt);
      }

      return options;
    } catch (Exception e) {
      throw new AuraHandledException(
        String.format(
          Label.JT_QueryViewerController_errorRetrievingConfigs,
          new List<String>{ e.getMessage() }
        )
      );
    }
  }

  /**
   * @description Executes a query based on configuration and bindings
   * @author Jaime Terrats | 11-28-2025
   * @param devName Configuration developer name
   * @param bindingsJson JSON string with bindings
   * @param runAsUserId Optional User ID to validate permissions context
   * @return QueryResult
   **/
  @AuraEnabled
  public static QueryResult executeQuery(
    String devName,
    String bindingsJson,
    String runAsUserId
  ) {
    try {
      // Validate Run As User feature
      if (String.isNotBlank(runAsUserId)) {
        validateRunAsPermission(runAsUserId);
      }

      Map<String, Object> bindings = deserializeBindings(bindingsJson);

      // Get config to check for LIKE clauses
      JT_DynamicQueryConfiguration__mdt config = [
        SELECT JT_BaseQuery__c
        FROM JT_DynamicQueryConfiguration__mdt
        WHERE DeveloperName = :devName
        WITH USER_MODE
        LIMIT 1
      ];

      // Auto-add wildcards for LIKE queries using centralized utility
      JT_QueryBindingUtil.addWildcardsForLikeBindings(
        config.JT_BaseQuery__c,
        bindings
      );

      List<SObject> sobjectRecords = JT_DataSelector.getRecords(
        devName,
        true,
        bindings
      );

      QueryResult result = new QueryResult();

      // ✅ SERIALIZE to preserve child relationships
      result.records = serializeRecordsForLWC(sobjectRecords);

      result.recordCount = sobjectRecords.size();
      result.success = true;
      result.runAsUserName = String.isNotBlank(runAsUserId)
        ? getUserName(runAsUserId)
        : null;

      // Extract field names from first record if available
      if (!sobjectRecords.isEmpty()) {
        result.fields = getFieldNames(sobjectRecords[0]);
      }

      return result;
    } catch (Exception e) {
      return createErrorResult(e);
    }
  }

  /**
   * @description Extracts field names from an SObject record IN ORDER
   * Maintains SELECT order by extracting only top-level fields, excluding child relationships
   * @author Jaime Terrats | 12-02-2025
   * @param record SObject record
   * @return List<String> Field names in the order they appear in the query
   **/
  private static List<String> getFieldNames(SObject record) {
    Map<String, Object> fieldMap = record.getPopulatedFieldsAsMap();
    List<String> fields = new List<String>();

    // Extract only scalar fields (exclude child relationships)
    for (String key : fieldMap.keySet()) {
      Object value = fieldMap.get(key);
      // Exclude 'attributes' and child relationships (which are lists)
      if (key != 'attributes' && !(value instanceof List<SObject>)) {
        fields.add(key);
      }
    }

    // ❌ DON'T sort - this loses SELECT order
    // fields.sort();

    return fields;
  }

  /**
   * @description Deserializes bindings JSON string to Map
   * Centralizes bindings deserialization to avoid duplication
   * @param bindingsJson JSON string with bindings
   * @return Map<String, Object> Deserialized bindings, or empty map if blank
   **/
  private static Map<String, Object> deserializeBindings(String bindingsJson) {
    return String.isNotBlank(bindingsJson)
      ? (Map<String, Object>) JSON.deserializeUntyped(bindingsJson)
      : new Map<String, Object>();
  }

  /**
   * @description Creates an error QueryResult with error message
   * Centralizes error result creation to avoid duplication
   * @param e Exception that occurred
   * @return QueryResult Error result with exception message
   **/
  private static QueryResult createErrorResult(Exception e) {
    QueryResult result = new QueryResult();
    result.success = false;
    result.errorMessage = e.getMessage();
    result.records = new List<Object>();
    result.recordCount = 0;
    return result;
  }

  /**
   * @description Serializes SObject records to LWC-friendly format using standard Salesforce JSON serialization
   * This method preserves child relationships in the standard Salesforce format: { records: [...] }
   * @author Jaime Terrats | 12-13-2025
   * @param sobjectRecords List of SObject records to serialize
   * @return List<Object> Serialized records compatible with LWC datatable
   **/
  public static List<Object> serializeRecordsForLWC(
    List<SObject> sobjectRecords
  ) {
    if (sobjectRecords == null || sobjectRecords.isEmpty()) {
      return new List<Object>();
    }

    // Use standard Salesforce JSON serialization to preserve child relationships
    // This ensures child relationships are in format: { records: [...] }
    String recordsJson = JSON.serialize(sobjectRecords);
    return (List<Object>) JSON.deserializeUntyped(recordsJson);
  }

  /**
   * @description Executes a query preview with LIMIT 5 for data preview
   * @author Jaime Terrats | 12-01-2025
   * @param devName Configuration developer name (optional if queryOverride provided)
   * @param bindingsJson JSON string with bindings
   * @param queryOverride Optional: Direct query string (for create modal preview)
   * @return QueryResult with max 5 records
   **/
  @AuraEnabled
  public static QueryResult executeQueryPreview(
    String devName,
    String bindingsJson,
    String queryOverride
  ) {
    try {
      Map<String, Object> bindings = deserializeBindings(bindingsJson);

      String baseQuery;

      // If queryOverride is provided, use it directly (for create modal preview)
      if (String.isNotBlank(queryOverride)) {
        baseQuery = queryOverride;
      } else {
        // Get the configuration to modify query with LIMIT
        JT_DynamicQueryConfiguration__mdt config = getConfigWithObjectName(
          devName
        );
        baseQuery = config.JT_BaseQuery__c;
      }

      // Auto-add wildcards for LIKE queries in preview using centralized utility
      JT_QueryBindingUtil.addWildcardsForLikeBindings(baseQuery, bindings);

      String previewQuery = baseQuery;

      // Add LIMIT 5 if not already present
      if (!previewQuery.containsIgnoreCase('LIMIT')) {
        previewQuery += ' LIMIT 5';
      } else {
        // Replace existing LIMIT with LIMIT 5
        previewQuery = previewQuery.replaceAll('(?i)LIMIT\\s+\\d+', 'LIMIT 5');
      }

      List<SObject> records = Database.queryWithBinds(
        previewQuery,
        bindings,
        AccessLevel.USER_MODE
      );

      QueryResult result = new QueryResult();
      result.records = records;
      result.recordCount = records.size();
      result.success = true;

      // Extract field names from first record if available
      if (!records.isEmpty()) {
        result.fields = getFieldNames(records[0]);
      }

      return result;
    } catch (Exception e) {
      QueryResult result = new QueryResult();
      result.success = false;
      result.records = new List<Object>(); // Changed from List<SObject>
      result.recordCount = 0;

      JT_ErrorMessageUtil.ErrorAnalysisResult analysis = JT_ErrorMessageUtil.analyzeError(
        e.getMessage(),
        null
      );

      switch on analysis.errorType {
        when OBJECT_ACCESS_DENIED {
          result.errorMessage = Label.JT_QueryViewerController_objectDoesNotExist;
        }
        when FIELD_ACCESS_DENIED {
          result.errorMessage = Label.JT_QueryViewerController_fieldsDoNotExist;
        }
        when INSUFFICIENT_PERMISSIONS {
          result.errorMessage = Label.JT_QueryViewerController_insufficientPermissions;
        }
        when INVALID_SOQL_SYNTAX {
          result.errorMessage = String.format(
            Label.JT_QueryViewerController_invalidSoqlSyntax,
            new List<String>{ e.getMessage() }
          );
        }
        when else {
          result.errorMessage = String.format(
            Label.JT_QueryViewerController_queryPreviewFailed,
            new List<String>{ e.getMessage() }
          );
        }
      }

      return result;
    }
  }

  /**
   * @description Extracts parameter names from a SOQL query
   * @author Jaime Terrats | 11-28-2025
   * @param query SOQL query string
   * @return List<String> Parameter names
   **/
  @AuraEnabled(cacheable=true)
  public static List<String> extractParameters(String query) {
    try {
      Set<String> params = new Set<String>();
      if (String.isBlank(query)) {
        return new List<String>();
      }

      // Normalize query: remove extra spaces around : for consistent parsing
      // Handles = :, =:, = : , etc.
      String normalizedQuery = query.replaceAll('\\s*:\\s*', ':');

      // Match patterns like :paramName (bind variables)
      // After normalization, all bind variables will be in format :paramName
      Pattern bindPattern = Pattern.compile(':([a-zA-Z_][a-zA-Z0-9_]*)');
      Matcher matcher = bindPattern.matcher(normalizedQuery);

      while (matcher.find()) {
        params.add(matcher.group(1));
      }

      List<String> paramList = new List<String>(params);
      paramList.sort();
      return paramList;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error extracting parameters: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Checks if current user can use Run As feature
   * @author Jaime Terrats | 11-28-2025
   * @return Boolean True if user can use Run As
   **/
  @AuraEnabled(cacheable=true)
  public static Boolean canUseRunAs() {
    try {
      // ✅ REFACTORED: Use Selector Layer (2025-12-02)
      return JT_SystemSelector.hasElevatedPermissions(UserInfo.getUserId()) ||
        isSystemAdmin();
    } catch (Exception e) {
      return false;
    }
  }

  /**
   * @description Checks if current user is a System Administrator
   * @author Jaime Terrats | 11-28-2025
   * @return Boolean True if user is admin
   **/
  private static Boolean isSystemAdmin() {
    try {
      // ✅ REFACTORED: Use Selector Layer (2025-12-02)
      Profile userProfile = JT_SystemSelector.getUserProfile();
      return userProfile != null &&
        userProfile.Name.contains(
          Label.JT_QueryViewerController_systemAdministrator
        );
    } catch (Exception e) {
      return false;
    }
  }

  /**
   * @description Gets ALL active users (excludes current user) for dropdown with client-side filtering
   * @author Jaime Terrats | 11-29-2025
   * @return List<UserOption> List of user options
   **/
  @AuraEnabled(cacheable=true)
  public static List<UserOption> getAllActiveUsers() {
    try {
      if (!canUseRunAs()) {
        throw new AuraHandledException(
          Label.JT_QueryViewerController_insufficientPermissionsRunAs
        );
      }

      Id currentUserId = UserInfo.getUserId();

      // ✅ REFACTORED: Use Selector Layer (2025-12-02)
      List<User> users = JT_SystemSelector.getAllActiveUsers();

      List<UserOption> options = new List<UserOption>();
      for (User u : users) {
        // Exclude current user
        if (u.Id == currentUserId) {
          continue;
        }

        UserOption opt = new UserOption();
        opt.value = u.Id;
        opt.label = u.Name + ' (' + u.Profile.Name + ')';
        opt.username = u.Username;
        opt.email = u.Email;
        opt.profileName = u.Profile.Name;
        options.add(opt);
      }

      return options;
    } catch (Exception e) {
      throw new AuraHandledException('Error loading users: ' + e.getMessage());
    }
  }

  /**
   * @description Validates Run As permission and user access
   * @author Jaime Terrats | 11-28-2025
   * @param userId User ID to validate
   **/
  private static void validateRunAsPermission(String userId) {
    if (!canUseRunAs()) {
      throw new AuraHandledException(
        'You do not have permission to use the Run As feature.'
      );
    }

    // ✅ REFACTORED: Use Selector Layer (2025-12-02)
    try {
      User u = JT_SystemSelector.getUserById(userId);

      if (!u.IsActive) {
        throw new AuraHandledException(
          'Cannot run as inactive user: ' + u.Name
        );
      }
    } catch (QueryException e) {
      throw new AuraHandledException('Selected user not found.');
    }
  }

  /**
   * @description Gets user name by ID
   * @author Jaime Terrats | 11-28-2025
   * @param userId User ID
   * @return String User name
   **/
  private static String getUserName(String userId) {
    try {
      // ✅ REFACTORED: Use Selector Layer (2025-12-02)
      User u = JT_SystemSelector.getUserById(userId);
      return u.Name;
    } catch (Exception e) {
      return null;
    }
  }

  /**
   * @description Wrapper class for configuration options
   **/
  public class ConfigurationOption {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String baseQuery;
    @AuraEnabled
    public String bindings;
    @AuraEnabled
    public String objectName;
  }

  /**
   * @description Wrapper class for query results
   **/
  /**
   * @description Wrapper class for query results
   * Uses List<Object> instead of List<SObject> to preserve child relationships
   */
  public class QueryResult {
    @AuraEnabled
    public List<Object> records; // Changed from List<SObject> to preserve child relationships
    @AuraEnabled
    public Integer recordCount;
    @AuraEnabled
    public List<String> fields;
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String errorMessage;
    @AuraEnabled
    public String runAsUserName;
  }

  /**
   * @description Wrapper class for user options
   **/
  public class UserOption {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String username;
    @AuraEnabled
    public String profileName;
    @AuraEnabled
    public String email;
  }

  /**
   * @description Detects if a query is potentially dangerous (might return >50K records)
   * @author Jaime Terrats | 12-02-2025
   * @param devName Configuration developer name
   * @param bindingsJson JSON string with bindings
   * @return QueryRiskAssessment
   **/
  /**
   * @description Detects if a query contains child relationships
   * @param query The SOQL query string
   * @return Boolean True if query has child relationships
   */
  private static Boolean hasChildRelationships(String query) {
    return query != null && query.containsIgnoreCase('(SELECT');
  }

  @AuraEnabled
  public static QueryRiskAssessment assessQueryRisk(
    String devName,
    String bindingsJson
  ) {
    try {
      Map<String, Object> bindings = deserializeBindings(bindingsJson);

      // Get config
      JT_DynamicQueryConfiguration__mdt config = getConfigWithAllFields(
        devName
      );

      // Merge bindings
      Map<String, Object> configBindings = String.isNotBlank(
          config.JT_Binding__c
        )
        ? (Map<String, Object>) JSON.deserializeUntyped(config.JT_Binding__c)
        : new Map<String, Object>();
      Map<String, Object> mergedBindings = new Map<String, Object>(
        configBindings
      );
      if (bindings != null) {
        mergedBindings.putAll(bindings);
      }

      // Create a DEEP COPY of bindings for COUNT with auto-added wildcards
      // Using JSON serialize/deserialize to ensure complete independence
      Map<String, Object> countBindings = (Map<String, Object>) JSON.deserializeUntyped(
        JSON.serialize(mergedBindings)
      );
      JT_QueryBindingUtil.addWildcardsForLikeBindings(
        config.JT_BaseQuery__c,
        countBindings
      );

      // Build COUNT query (replace SELECT ... FROM with SELECT COUNT() FROM)
      // Use [\s\S]*? to match across multiple lines (including newlines)
      // Decode HTML entities that may come from metadata
      String baseQuery = config.JT_BaseQuery__c.replace('&gt;', '>')
        .replace('&lt;', '<')
        .replace('&amp;', '&');
      String countQuery = baseQuery
        .replaceAll('(?i)SELECT[\\s\\S]+?FROM', 'SELECT COUNT() FROM')
        .replaceAll('(?i)ORDER\\s+BY[\\s\\S]*$', '') // Remove ORDER BY
        .replaceAll('(?i)LIMIT\\s+\\d+[\\s\\S]*$', ''); // Remove LIMIT

      // Execute count query with timeout protection
      Integer estimatedCount = 0;
      String finalCountQuery = null;
      try {
        // Remove conditions for empty/missing bindings, then let Database.countQueryWithBinds
        // bind the rest directly - no bind value is ever interpolated into the query string.
        finalCountQuery = removeEmptyBindingConditions(
          countQuery,
          countBindings
        );

        // Remove Long Text Area field conditions that cannot be filtered in COUNT queries
        finalCountQuery = removeLongTextAreaConditions(finalCountQuery);

        System.debug(LoggingLevel.DEBUG, 'COUNT query: ' + finalCountQuery);

        estimatedCount = Database.countQueryWithBinds(
          finalCountQuery,
          countBindings,
          AccessLevel.USER_MODE
        );

        System.debug(LoggingLevel.DEBUG, 'COUNT result: ' + estimatedCount);
      } catch (Exception e) {
        // If count fails, check if it's a Long Text Area field error and retry without it
        if (
          e.getMessage() != null &&
          e.getMessage().contains('can not be filtered in a query call')
        ) {
          System.debug(
            LoggingLevel.WARN,
            'COUNT query failed due to unfilterable field, retrying without Long Text Area conditions: ' +
            e.getMessage()
          );
          try {
            // Remove Long Text Area conditions and retry
            finalCountQuery = removeLongTextAreaConditions(finalCountQuery);
            estimatedCount = Database.countQuery(finalCountQuery);
            System.debug(
              LoggingLevel.DEBUG,
              'COUNT result after removing Long Text Area conditions: ' +
              estimatedCount
            );
          } catch (Exception retryException) {
            // If retry also fails, check if query has specific filters
            System.debug(
              LoggingLevel.WARN,
              'COUNT query failed after retry: ' + retryException.getMessage()
            );

            // Check if query has WHERE clause with specific filters
            Boolean hasWhereClause =
              baseQuery != null &&
              baseQuery.containsIgnoreCase('WHERE') &&
              !baseQuery.containsIgnoreCase('WHERE 1=1') &&
              !baseQuery.containsIgnoreCase('WHERE TRUE');

            // Check if bindings are provided and not empty
            Boolean hasValidBindings =
              countBindings != null &&
              !countBindings.isEmpty() &&
              !hasEmptyRequiredParameters(countBindings);

            // If query has WHERE clause with valid bindings, assume low risk
            if (hasWhereClause && hasValidBindings) {
              estimatedCount = 10000; // Medium risk threshold
              System.debug(
                LoggingLevel.INFO,
                'COUNT query failed after retry but has WHERE clause with bindings. Assuming medium risk (10k records).'
              );
            } else {
              estimatedCount = 99999; // Critical risk
              System.debug(
                LoggingLevel.WARN,
                'COUNT query failed after retry and has no specific filters. Assuming critical risk (99k records).'
              );
            }
          }
        } else {
          // If count fails for other reasons, check if query has specific filters
          // If query has WHERE conditions with bindings, it's likely safe (low count)
          // Only assume risky if query has no filters or filters are empty
          System.debug(
            LoggingLevel.WARN,
            'COUNT query failed: ' + e.getMessage()
          );
          System.debug(
            LoggingLevel.WARN,
            'COUNT query that failed: ' +
            (finalCountQuery != null ? finalCountQuery : 'null')
          );

          // Check if query has WHERE clause with specific filters
          Boolean hasWhereClause =
            baseQuery != null &&
            baseQuery.containsIgnoreCase('WHERE') &&
            !baseQuery.containsIgnoreCase('WHERE 1=1') &&
            !baseQuery.containsIgnoreCase('WHERE TRUE');

          // Check if bindings are provided and not empty
          Boolean hasValidBindings =
            countBindings != null &&
            !countBindings.isEmpty() &&
            !hasEmptyRequiredParameters(countBindings);

          // If query has WHERE clause with valid bindings, assume low risk
          // Otherwise, assume high risk (could be scanning all records)
          if (hasWhereClause && hasValidBindings) {
            // Query has specific filters - likely returns few records
            // Use a conservative estimate (medium risk) instead of critical
            estimatedCount = 10000; // Medium risk threshold
            System.debug(
              LoggingLevel.INFO,
              'COUNT query failed but has WHERE clause with bindings. Assuming medium risk (10k records).'
            );
          } else {
            // No filters or empty bindings - could be scanning all records
            estimatedCount = 99999; // Critical risk
            System.debug(
              LoggingLevel.WARN,
              'COUNT query failed and has no specific filters. Assuming critical risk (99k records).'
            );
          }
        }
      }

      final QueryRiskAssessment assessment = new QueryRiskAssessment();
      assessment.estimatedRecordCount = estimatedCount;
      assessment.hasEmptyParameters = hasEmptyParameters(mergedBindings);

      // CRITICAL: Batch processing breaks child relationships
      final Boolean hasChildRelationships = hasChildRelationships(
        config.JT_BaseQuery__c
      );

      if (hasChildRelationships) {
        setLowRiskAssessment(
          assessment,
          Label.JT_QueryViewerController_queryContainsChildRelationships
        );
      } else {
        assessRiskByCount(assessment, estimatedCount);
      }

      return assessment;
    } catch (Exception e) {
      final QueryRiskAssessment assessment = new QueryRiskAssessment();
      assessment.estimatedRecordCount = 0;
      assessment.isHighRisk = true;
      assessment.isCriticalRisk = false;
      assessment.recommendBatchProcessing = true;
      assessment.riskLevel = Label.JT_QueryViewerController_riskLevelUnknown;
      assessment.message = String.format(
        Label.JT_QueryViewerController_unableToAssessRisk,
        new List<String>{ e.getMessage() }
      );
      return assessment;
    }
  }

  /**
   * @description Removes WHERE conditions for bindings that are missing/empty, leaving the
   * rest of the query's bind placeholders intact for Database.countQueryWithBinds - no bind
   * value is ever interpolated into the query string.
   * @param query The SOQL query string with bind variables
   * @param bindings The map of bind variables
   * @return String Query with empty-binding conditions removed
   **/
  private static String removeEmptyBindingConditions(
    String query,
    Map<String, Object> bindings
  ) {
    if (String.isBlank(query)) {
      return query;
    }

    String result = query;

    // First, find all bindings referenced in the query
    // Handle both "=:name" and "=: name" (with optional space after colon)
    Pattern bindingPattern = Pattern.compile(':\\s*(\\w+)\\b');
    Matcher matcher = bindingPattern.matcher(query);
    Set<String> referencedBindings = new Set<String>();
    while (matcher.find()) {
      referencedBindings.add(matcher.group(1));
    }

    // Remove conditions for bindings that don't exist or are empty
    for (String bindingKey : referencedBindings) {
      Boolean shouldRemove = false;

      if (bindings == null || !bindings.containsKey(bindingKey)) {
        // Binding not provided - remove the condition
        shouldRemove = true;
      } else {
        Object value = bindings.get(bindingKey);
        // Check if value is empty/null
        Boolean isEmpty =
          value == null ||
          (value instanceof String && String.isBlank((String) value)) ||
          (value instanceof List<Object> && ((List<Object>) value).isEmpty());

        if (isEmpty) {
          // Binding is empty - remove the condition
          shouldRemove = true;
        }
      }

      if (shouldRemove) {
        result = removeConditionForBinding(result, bindingKey);
      }
    }

    return result;
  }

  /**
   * @description Removes WHERE conditions for Text Area and Long Text Area fields that cannot be filtered in COUNT queries
   * @param query The SOQL query string
   * @return String Query with Text Area and Long Text Area conditions removed
   */
  @TestVisible
  private static String removeLongTextAreaConditions(String query) {
    if (String.isBlank(query)) {
      return query;
    }

    String result = query;

    // Common Text Area and Long Text Area field names that cannot be filtered in COUNT queries
    // These field types cannot be used in WHERE clauses for COUNT queries in Salesforce
    List<String> textAreaFields = new List<String>{
      'Description',
      'Body',
      'Content',
      'LongTextArea',
      'RichTextArea',
      'TextArea',
      'CommentBody',
      'MessageBody',
      'HtmlValue',
      'PlainTextBody'
    };

    // Remove conditions for each Text Area and Long Text Area field
    for (String fieldName : textAreaFields) {
      // Pattern: (AND|OR)? FieldName LIKE 'value' (AND|OR)?
      // Match field name case-insensitively and capture the entire condition including quoted values
      // This handles both bindings (:binding) and already-replaced values ('value')
      Pattern conditionPattern = Pattern.compile(
        '(?i)(?s)(?:\\s+(?:AND|OR))?\\s+' +
          Pattern.quote(fieldName) +
          '\\s+(?:LIKE|IN|NOT\\s+IN|INCLUDES|EXCLUDES|[=<>!]+)\\s+(?:\'[^\']*\'|\\([^)]+\\)|:[a-zA-Z0-9_]+|\\S+)(?:\\s+(?:AND|OR))?(?=\\s+(?:AND|OR|ORDER|LIMIT|GROUP|HAVING|$)|$)'
      );

      Matcher matcher = conditionPattern.matcher(result);
      if (matcher.find()) {
        String matchedCondition = matcher.group(0);

        // Check if there's AND/OR after the condition that we need to remove
        String afterMatch = result.substring(matcher.end());
        Pattern trailingAndOrPattern = Pattern.compile(
          '(?i)^\\s+(AND|OR)\\s+(?![a-z])'
        );
        Matcher trailingMatcher = trailingAndOrPattern.matcher(afterMatch);
        Integer additionalLength = 0;
        if (trailingMatcher.find()) {
          String trailing = trailingMatcher.group(0);
          // Only remove trailing AND/OR if it's not followed by ORDER, LIMIT, etc.
          if (
            !Pattern.compile('(?i)^\\s+(AND|OR)\\s+(ORDER|LIMIT|GROUP|HAVING)')
              .matcher(afterMatch)
              .find()
          ) {
            additionalLength = trailing.length();
          }
        }

        result =
          result.substring(0, matcher.start()) +
          result.substring(matcher.end() + additionalLength);

        // Clean up any double AND/OR that might result
        result = result.replaceAll('(?i)\\s+AND\\s+AND\\s+', ' AND ');
        result = result.replaceAll('(?i)\\s+OR\\s+OR\\s+', ' OR ');
        result = result.replaceAll('(?i)\\s+AND\\s+OR\\s+', ' AND ');
        result = result.replaceAll('(?i)\\s+OR\\s+AND\\s+', ' AND ');

        // Clean up WHERE with nothing after it or with AND/OR immediately after
        result = result.replaceAll(
          '(?i)\\s+WHERE\\s+(?:AND|OR)\\s+',
          ' WHERE '
        );
        result = result.replaceAll('(?i)\\s+WHERE\\s*$', '');

        // Clean up trailing AND/OR before ORDER BY, LIMIT, etc.
        result = result.replaceAll(
          '(?i)\\s+(?:AND|OR)\\s+(?=ORDER\\s+BY|LIMIT|GROUP\\s+BY|HAVING|$)',
          ' '
        );
      }
    }

    return result;
  }

  /**
   * @description Removes a WHERE condition for a binding that doesn't exist or is empty
   * @param query The SOQL query string
   * @param bindingKey The binding variable name (without colon)
   * @return String Query with condition removed
   */
  @TestVisible
  private static String removeConditionForBinding(
    String query,
    String bindingKey
  ) {
    if (String.isBlank(query) || String.isBlank(bindingKey)) {
      return query;
    }

    String result = query;
    String bindingPattern = ':' + bindingKey;

    // Match condition with optional AND/OR before and after
    // Use negative lookahead to avoid capturing OR from ORDER BY
    // Pattern: (AND|OR)? Field (IN|NOT IN|...) :binding (AND|OR)?
    // But don't capture OR if it's part of ORDER BY
    Pattern conditionPattern = Pattern.compile(
      '(?i)(?s)(?:\\s+(?:AND|OR))?\\s+[a-z0-9_]+\\s+(?:IN|NOT\\s+IN|INCLUDES|EXCLUDES|[=<>!]+)\\s*' +
        Pattern.quote(bindingPattern) +
        '\\b(?=\\s+(?:AND|OR|ORDER|LIMIT|GROUP|HAVING|$)|$)'
    );

    Matcher matcher = conditionPattern.matcher(result);
    if (matcher.find()) {
      String matchedCondition = matcher.group(0);

      // Check if there's AND/OR after the binding that we need to remove
      String afterMatch = result.substring(matcher.end());
      Pattern trailingAndOrPattern = Pattern.compile(
        '(?i)^\\s+(AND|OR)\\s+(?![a-z])'
      );
      Matcher trailingMatcher = trailingAndOrPattern.matcher(afterMatch);
      Integer additionalLength = 0;
      if (trailingMatcher.find()) {
        String trailing = trailingMatcher.group(0);
        // Only remove trailing AND/OR if it's not followed by ORDER, LIMIT, etc.
        if (
          !Pattern.compile('(?i)^\\s+(AND|OR)\\s+(ORDER|LIMIT|GROUP|HAVING)')
            .matcher(afterMatch)
            .find()
        ) {
          additionalLength = trailing.length();
        }
      }

      result =
        result.substring(0, matcher.start()) +
        result.substring(matcher.end() + additionalLength);

      // Clean up any double AND/OR that might result
      result = result.replaceAll('(?i)\\s+AND\\s+AND\\s+', ' AND ');
      result = result.replaceAll('(?i)\\s+OR\\s+OR\\s+', ' OR ');
      result = result.replaceAll('(?i)\\s+AND\\s+OR\\s+', ' AND ');
      result = result.replaceAll('(?i)\\s+OR\\s+AND\\s+', ' AND ');

      // Clean up WHERE with nothing after it or with AND/OR immediately after
      result = result.replaceAll('(?i)\\s+WHERE\\s+(?:AND|OR)\\s+', ' WHERE ');
      result = result.replaceAll('(?i)\\s+WHERE\\s*$', '');

      // Clean up trailing AND/OR before ORDER BY, LIMIT, etc.
      result = result.replaceAll(
        '(?i)\\s+(?:AND|OR)\\s+(?=ORDER\\s+BY|LIMIT|GROUP\\s+BY|HAVING|$)',
        ' '
      );
    }

    return result;
  }

  /**
   * @description Gets the type name of a value for debug messages
   * @param value Value to get type name for
   * @return String Type name
   */
  @TestVisible
  private static String getValueTypeName(Object value) {
    if (value == null) {
      return 'null';
    }
    if (value instanceof String) {
      return 'String';
    }
    if (value instanceof Integer) {
      return 'Integer';
    }
    if (value instanceof Decimal) {
      return 'Decimal';
    }
    if (value instanceof Boolean) {
      return 'Boolean';
    }
    if (value instanceof Date) {
      return 'Date';
    }
    if (value instanceof Datetime) {
      return 'Datetime';
    }
    if (value instanceof List<Object>) {
      return 'List<Object>';
    }
    return 'Object';
  }

  /**
   * @description Converts binding value to appropriate type based on query context
   * Detects numeric comparisons and converts string values to Decimal/Integer
   * @param query The SOQL query string
   * @param bindingKey The binding variable name
   * @param value The binding value (may be String from JSON)
   * @return Object Converted value with appropriate type
   */
  @TestVisible
  private static Object convertBindingValueForQuery(
    String query,
    String bindingKey,
    Object value
  ) {
    if (value == null) {
      return value;
    }

    // Decode HTML entities that may come from metadata (e.g., &gt;= becomes >=, &lt;= becomes <=)
    String decodedQuery = query.replace('&gt;', '>')
      .replace('&lt;', '<')
      .replace('&amp;', '&');
    String normalizedQuery = decodedQuery.toLowerCase();
    String bindingPattern = ':' + bindingKey;
    // Normalize binding pattern for regex matching (query is normalized to lowercase)
    String normalizedBindingPattern = ':' + bindingKey.toLowerCase();
    String escapedPattern = Pattern.quote(normalizedBindingPattern);

    // Check if binding is used in numeric comparison operators
    Boolean isNumericComparison = false;
    Pattern pattern1 = Pattern.compile(
      '(?i)(?s)[a-z0-9_]+\\s+[>=<]+\\s*' + escapedPattern + '\\b'
    );
    Matcher matcher1 = pattern1.matcher(normalizedQuery);
    if (matcher1.find()) {
      isNumericComparison = true;
    }

    if (!isNumericComparison) {
      Pattern pattern2 = Pattern.compile(
        '(?i)(?s)\\b' + escapedPattern + '\\s*[>=<]+\\s+[a-z0-9_]+'
      );
      Matcher matcher2 = pattern2.matcher(normalizedQuery);
      if (matcher2.find()) {
        isNumericComparison = true;
      }
    }

    // Check for boolean comparisons first (before numeric, to avoid false positives)
    // Handle both "Field = :binding" and "Field =: binding" (with optional space after =)
    Boolean isBooleanComparison = false;
    Pattern boolPattern1 = Pattern.compile(
      '[a-z0-9_]+\\s*[=!]?=\\s*' + escapedPattern + '\\b'
    );
    Matcher boolMatcher1 = boolPattern1.matcher(normalizedQuery);
    if (boolMatcher1.find()) {
      isBooleanComparison = true;
    }

    if (!isBooleanComparison) {
      Pattern boolPattern2 = Pattern.compile(
        '\\b' + escapedPattern + '\\s*[=!]?=\\s*[a-z0-9_]+'
      );
      Matcher boolMatcher2 = boolPattern2.matcher(normalizedQuery);
      if (boolMatcher2.find()) {
        isBooleanComparison = true;
      }
    }

    // Also check if the field name suggests it's a boolean field (starts with Is, Has, Can, etc.)
    // Handle both "Field = :binding" and "Field =: binding" (with optional space after =)
    if (!isBooleanComparison) {
      // Pattern to match field names that suggest boolean (Is*, Has*, Can*, etc.)
      // Match: iscustomerportal = :isportal or iscustomerportal=:isportal
      Pattern boolFieldPattern = Pattern.compile(
        '\\b(is|has|can|should|will|was|were|did|does|contains|includes|enabled|disabled|active|inactive|visible|hidden|required|optional)[a-z0-9_]*\\s*[=!]?=\\s*' +
          escapedPattern +
          '\\b'
      );
      Matcher boolFieldMatcher = boolFieldPattern.matcher(normalizedQuery);
      if (boolFieldMatcher.find()) {
        isBooleanComparison = true;
      }
    }

    // Handle boolean values (JavaScript already sends Boolean, but handle String legacy)
    if (isBooleanComparison) {
      if (value instanceof Boolean) {
        return value; // Already boolean from JavaScript
      } else if (value instanceof String) {
        String trimmedValue = ((String) value).trim().toLowerCase();
        if (
          trimmedValue == 'true' ||
          trimmedValue == '1' ||
          trimmedValue == 'yes'
        ) {
          return true;
        } else if (
          trimmedValue == 'false' ||
          trimmedValue == '0' ||
          trimmedValue == 'no'
        ) {
          return false;
        }
        // If string is not "true" or "false", return as-is (might be field name or other value)
        return value;
      }
    }

    // If not detected as boolean comparison but value is string "true"/"false" and field suggests boolean,
    // still try to convert (fallback for edge cases)
    // This handles cases where the pattern didn't match but we know it's a boolean field
    if (!isBooleanComparison && value instanceof String) {
      String trimmedValue = ((String) value).trim().toLowerCase();
      // Check if field name suggests boolean (starts with Is, Has, Can, etc.)
      // Look for field name before the binding in the WHERE clause
      Pattern boolFieldCheck = Pattern.compile(
        '\\b(is|has|can|should|will|was|were|did|does|contains|includes|enabled|disabled|active|inactive|visible|hidden|required|optional)[a-z0-9_]*\\s*[=!]?=\\s*' +
          escapedPattern +
          '\\b'
      );
      Matcher boolFieldCheckMatcher = boolFieldCheck.matcher(normalizedQuery);
      if (boolFieldCheckMatcher.find()) {
        // Field name suggests boolean, convert string to boolean
        if (
          trimmedValue == 'true' ||
          trimmedValue == '1' ||
          trimmedValue == 'yes'
        ) {
          return true;
        } else if (
          trimmedValue == 'false' ||
          trimmedValue == '0' ||
          trimmedValue == 'no'
        ) {
          return false;
        }
      }
    }

    if (!isNumericComparison) {
      Pattern pattern3 = Pattern.compile(
        '(?i)(?s)[a-z0-9_]+\\s*[=!]+=\\s*' +
          escapedPattern +
          '\\b|\\b' +
          escapedPattern +
          '\\s*[=!]+=\\s+[a-z0-9_]+'
      );
      Matcher matcher3 = pattern3.matcher(normalizedQuery);
      if (matcher3.find()) {
        // Check if value is numeric (Decimal, Integer, or numeric String)
        // Skip if we already handled as boolean
        if (!isBooleanComparison) {
          if (value instanceof Decimal || value instanceof Integer) {
            isNumericComparison = true;
          } else if (value instanceof String) {
            String trimmedValue = ((String) value).trim().replace(',', '');
            if (isNumericString(trimmedValue)) {
              isNumericComparison = true;
            }
          }
        }
      }
    }

    if (isNumericComparison) {
      // If value is already Integer, no conversion needed
      if (value instanceof Integer) {
        return value;
      }

      // Handle Decimal -> Integer conversion based on field type
      if (value instanceof Decimal) {
        Boolean isIntegerField = isIntegerFieldBinding(
          decodedQuery,
          bindingKey
        );
        if (isIntegerField) {
          return ((Decimal) value).intValue();
        }
        return value; // Keep as Decimal
      }

      // Legacy: Handle String values (shouldn't happen if JS sends typed values)
      if (value instanceof String) {
        String stringValue = ((String) value).trim().replace(',', '');
        if (String.isBlank(stringValue)) {
          return value;
        }
        if (!isNumericString(stringValue)) {
          return value;
        }
        try {
          Boolean isIntegerField = isIntegerFieldBinding(
            decodedQuery,
            bindingKey
          );
          if (isIntegerField) {
            return Integer.valueOf(stringValue);
          } else {
            return Decimal.valueOf(stringValue);
          }
        } catch (Exception e) {
          return value;
        }
      }
    }

    // Check for date/datetime comparisons and convert ISO strings
    Boolean isDateComparison = isDateFieldBinding(decodedQuery, bindingKey);
    Boolean isDatetimeComparison = isDatetimeFieldBinding(
      decodedQuery,
      bindingKey
    );

    String valueTypeName = value instanceof String
      ? 'String'
      : value instanceof Integer
          ? 'Integer'
          : value instanceof Decimal
              ? 'Decimal'
              : value instanceof Boolean
                  ? 'Boolean'
                  : value instanceof Date
                      ? 'Date'
                      : value instanceof Datetime
                          ? 'Datetime'
                          : value != null ? 'Object' : 'null';
    System.debug(
      LoggingLevel.DEBUG,
      'convertBindingValueForQuery: bindingKey=' +
        bindingKey +
        ', value type=' +
        valueTypeName +
        ', isDateComparison=' +
        isDateComparison +
        ', isDatetimeComparison=' +
        isDatetimeComparison
    );

    if ((isDateComparison || isDatetimeComparison) && value instanceof String) {
      String stringValue = ((String) value).trim();
      if (!String.isBlank(stringValue)) {
        try {
          // Try to parse ISO 8601 format (from JavaScript toISOString())
          // Format: YYYY-MM-DDTHH:mm:ss.sssZ or YYYY-MM-DDTHH:mm:ssZ
          if (isDatetimeComparison) {
            // Convert ISO string to Datetime
            // JavaScript toISOString() format: "2024-01-15T10:30:00.000Z" or "2024-01-15T10:30:00Z"
            // DateTime.ValueofGmt() expects: "yyyy-MM-dd HH:mm:ss" in GMT
            String normalizedDate = stringValue;
            // Remove timezone offset if present (+HH:mm or -HH:mm)
            normalizedDate = normalizedDate.replaceAll(
              '[+-]\\d{2}:\\d{2}$',
              ''
            );
            // Replace 'T' with space (required for ValueofGmt)
            normalizedDate = normalizedDate.replace('T', ' ');
            // Remove 'Z' at the end
            normalizedDate = normalizedDate.replace('Z', '');
            // Remove milliseconds if present (.000) - must be at the end after removing Z
            normalizedDate = normalizedDate.replaceAll('\\.\\d{1,3}$', '');
            // Trim any trailing spaces
            normalizedDate = normalizedDate.trim();
            // Parse to Datetime using ValueofGmt (handles ISO format better than valueOf)
            System.debug(
              LoggingLevel.DEBUG,
              'Converting ISO date string: "' +
                stringValue +
                '" to "' +
                normalizedDate +
                '"'
            );
            Datetime dt = DateTime.ValueofGmt(normalizedDate);
            System.debug(LoggingLevel.DEBUG, 'Converted to Datetime: ' + dt);
            return dt;
          } else if (isDateComparison) {
            // For Date fields, extract just the date part (YYYY-MM-DD)
            String datePart = stringValue.split('T')[0];
            return Date.valueOf(datePart);
          }
        } catch (Exception e) {
          System.debug(
            LoggingLevel.WARN,
            'Failed to parse date/datetime string "' +
              stringValue +
              '": ' +
              e.getMessage()
          );
          return value; // Return as-is if parsing fails
        }
      }
    }

    return value;
  }

  /**
   * @description Checks if a binding is used with a Date field
   * Common Date fields: CloseDate, StartDate, EndDate, etc.
   * @param query The SOQL query string
   * @param bindingKey The binding variable name
   * @return Boolean True if the binding is likely used with a Date field
   */
  @TestVisible
  private static Boolean isDateFieldBinding(String query, String bindingKey) {
    String bindingPattern = ':' + bindingKey;
    String normalizedQuery = query.toLowerCase();
    // Normalize binding pattern for regex matching (query is normalized to lowercase)
    String normalizedBindingPattern = ':' + bindingKey.toLowerCase();
    String escapedPattern = Pattern.quote(normalizedBindingPattern);

    // Common Date field names in Salesforce
    List<String> dateFieldNames = new List<String>{
      'closedate',
      'startdate',
      'enddate',
      'birthdate',
      'hiredate',
      'terminationdate',
      'date'
    };

    // Check if binding is used with any Date field
    for (String fieldName : dateFieldNames) {
      // Pattern: fieldName = :binding or fieldName != :binding, etc.
      Pattern pattern = Pattern.compile(
        '(?i)(?s)\\b' +
          fieldName +
          '\\s*[=!<>]+\\s*' +
          escapedPattern +
          '\\b|\\b' +
          escapedPattern +
          '\\s*[=!<>]+\\s+' +
          fieldName +
          '\\b'
      );
      Matcher matcher = pattern.matcher(normalizedQuery);
      if (matcher.find()) {
        return true;
      }
    }

    return false;
  }

  /**
   * @description Checks if a binding is used with a Datetime field
   * Common Datetime fields: CreatedDate, LastModifiedDate, etc.
   * @param query The SOQL query string
   * @param bindingKey The binding variable name
   * @return Boolean True if the binding is likely used with a Datetime field
   */
  @TestVisible
  private static Boolean isDatetimeFieldBinding(
    String query,
    String bindingKey
  ) {
    String bindingPattern = ':' + bindingKey;
    String normalizedQuery = query.toLowerCase();
    // Normalize binding pattern for regex matching (query is normalized to lowercase)
    String normalizedBindingPattern = ':' + bindingKey.toLowerCase();
    String escapedPattern = Pattern.quote(normalizedBindingPattern);

    // Common Datetime field names in Salesforce
    List<String> datetimeFieldNames = new List<String>{
      'createddate',
      'lastmodifieddate',
      'systemmodstamp',
      'lastactivitydate',
      'lastvieweddate',
      'lastreferenceddate',
      'datetime',
      'timestamp'
    };

    // Check if binding is used with any Datetime field
    for (String fieldName : datetimeFieldNames) {
      // Pattern: fieldName = :binding or fieldName != :binding, etc.
      Pattern pattern = Pattern.compile(
        '(?i)(?s)\\b' +
          fieldName +
          '\\s*[=!<>]+\\s*' +
          escapedPattern +
          '\\b|\\b' +
          escapedPattern +
          '\\s*[=!<>]+\\s+' +
          fieldName +
          '\\b'
      );
      Matcher matcher = pattern.matcher(normalizedQuery);
      if (matcher.find()) {
        return true;
      }
    }

    return false;
  }

  /**
   * @description Checks if a binding is used with an Integer field
   * Common Integer fields: NumberOfEmployees, etc.
   * @param query The SOQL query string
   * @param bindingKey The binding variable name
   * @return Boolean True if the binding is likely used with an Integer field
   */
  @TestVisible
  private static Boolean isIntegerFieldBinding(
    String query,
    String bindingKey
  ) {
    String bindingPattern = ':' + bindingKey;
    String normalizedQuery = query.toLowerCase();
    // Normalize binding pattern for regex matching (query is normalized to lowercase)
    String normalizedBindingPattern = ':' + bindingKey.toLowerCase();
    String escapedPattern = Pattern.quote(normalizedBindingPattern);

    // Common Integer field names in Salesforce
    List<String> integerFieldNames = new List<String>{
      'numberofemployees',
      'number_of_employees',
      'employee_count',
      'count',
      'quantity',
      'qty'
    };

    // Check if binding is used with any Integer field
    for (String fieldName : integerFieldNames) {
      // Pattern: fieldName >= :binding or fieldName <= :binding, etc.
      Pattern pattern = Pattern.compile(
        '(?i)(?s)\\b' +
          fieldName +
          '\\s+[>=<]+\\s*' +
          escapedPattern +
          '\\b|\\b' +
          escapedPattern +
          '\\s*[>=<]+\\s+' +
          fieldName +
          '\\b'
      );
      Matcher matcher = pattern.matcher(normalizedQuery);
      if (matcher.find()) {
        return true;
      }
    }

    return false;
  }

  /**
   * @description Checks if a string represents a numeric value
   * @param value String value to check
   * @return Boolean True if the string can be converted to a number
   */
  @TestVisible
  private static Boolean isNumericString(String value) {
    if (String.isBlank(value)) {
      return false;
    }
    // Remove commas and trim before checking
    String trimmedValue = value.trim().replace(',', '');
    if (String.isBlank(trimmedValue)) {
      return false;
    }
    // Check if it matches a numeric pattern (digits, optional decimal point, optional sign)
    Pattern numericPattern = Pattern.compile('^-?\\d+(\\.\\d+)?$');
    Matcher matcher = numericPattern.matcher(trimmedValue);
    return matcher.matches();
  }

  /**
   * @description Escapes a binding value for use in SOQL query string replacement
   * @param value Value to escape
   * @return String Escaped value ready for SOQL
   */
  @TestVisible
  private static String escapeBindingValue(Object value) {
    if (value == null) {
      return 'null';
    }

    if (value instanceof List<Object>) {
      return escapeListValue((List<Object>) value);
    }

    return escapeScalarValue(value);
  }

  /**
   * @description Escapes a list value for use in IN/NOT IN clauses
   * @param listValue List to escape
   * @return String Escaped list format: (value1, value2, ...)
   */
  @TestVisible
  private static String escapeListValue(List<Object> listValue) {
    List<String> escapedValues = new List<String>();
    for (Object item : listValue) {
      escapedValues.add(escapeScalarValue(item));
    }
    return '(' + String.join(escapedValues, ',') + ')';
  }

  /**
   * @description Escapes a scalar value for use in SOQL
   * @param value Scalar value to escape
   * @return String Escaped value
   */
  @TestVisible
  private static String escapeScalarValue(Object value) {
    if (value == null) {
      return 'null';
    }

    if (value instanceof String) {
      return '\'' + String.escapeSingleQuotes((String) value) + '\'';
    }

    if (
      value instanceof Boolean ||
      value instanceof Integer ||
      value instanceof Decimal
    ) {
      return String.valueOf(value);
    }

    if (value instanceof Date) {
      return String.valueOf((Date) value);
    }

    if (value instanceof Datetime) {
      return ((Datetime) value).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    return '\'' + String.escapeSingleQuotes(String.valueOf(value)) + '\'';
  }

  /**
   * @description Adds wildcards to bind parameters used in LIKE clauses for risk assessment
   * @param query The SOQL query string
   * @param bindings The map of bind variables
   **/
  /**
   * @description Adds wildcards to bind parameters used in LIKE clauses
   * Delegates to JT_QueryBindingUtil for consistency
   * @deprecated Use JT_QueryBindingUtil.addWildcardsForLikeBindings instead
   * @param query The SOQL query string
   * @param bindings The map of bind variables
   **/
  public static void addWildcardsForLikeBindings(
    String query,
    Map<String, Object> bindings
  ) {
    JT_QueryBindingUtil.addWildcardsForLikeBindings(query, bindings);
  }

  /**
   * @description Executes query using batch/cursor processing for large result sets
   * @author Jaime Terrats | 12-02-2025
   * @param devName Configuration developer name
   * @param bindingsJson JSON string with bindings
   * @param batchSize Records per batch (default: 200)
   * @return QueryResult
   **/
  @AuraEnabled
  public static QueryResult executeQueryWithBatchProcessing(
    String devName,
    String bindingsJson,
    Integer batchSize
  ) {
    try {
      Map<String, Object> bindings = deserializeBindings(bindingsJson);

      // Get config to check for LIKE clauses
      JT_DynamicQueryConfiguration__mdt config = [
        SELECT JT_BaseQuery__c
        FROM JT_DynamicQueryConfiguration__mdt
        WHERE DeveloperName = :devName
        WITH USER_MODE
        LIMIT 1
      ];

      // Auto-add wildcards for LIKE queries in batch processing using centralized utility
      JT_QueryBindingUtil.addWildcardsForLikeBindings(
        config.JT_BaseQuery__c,
        bindings
      );

      Integer effectiveBatchSize = batchSize != null &&
        batchSize > 0
        ? batchSize
        : 200;

      // Use ResultCollector to accumulate records
      ResultCollector collector = new ResultCollector();

      JT_DataSelector.CursorProcessingParams cursorParams = new JT_DataSelector.CursorProcessingParams(
        devName,
        bindings,
        true, // enforce security
        effectiveBatchSize,
        collector
      );
      Integer totalProcessed = JT_DataSelector.processRecordsWithCursor(
        cursorParams
      );

      // Return collected results
      QueryResult result = new QueryResult();

      List<SObject> sobjectRecords = collector.getAllRecords();

      // ✅ SERIALIZE to preserve child relationships
      String recordsJson = JSON.serialize(sobjectRecords);
      result.records = (List<Object>) JSON.deserializeUntyped(recordsJson);

      result.recordCount = totalProcessed;
      result.success = true;

      // Extract field names from first record
      if (sobjectRecords != null && !sobjectRecords.isEmpty()) {
        result.fields = getFieldNames(sobjectRecords[0]);
      }

      return result;
    } catch (Exception e) {
      return createErrorResult(e);
    }
  }

  /**
   * @description Starts a chained, multi-transaction LDV operation and returns immediately
   * with its operation id - it does not wait for any chunk to complete. Poll
   * getLdvOperationStatus(operationId) for progress. Intended for export/integration workloads
   * whose CursorProcessor does its own side-effecting work per chunk; interactive UI browsing
   * of results is not wired to this path yet.
   * @author Jaime Terrats
   * @param devName Configuration developer name
   * @param bindingsJson JSON string with bindings
   * @param batchSize Records per chunk (default 200)
   * @param processorClassName Fully-qualified JT_DataSelector.CursorProcessor implementation
   * with a public no-arg constructor (e.g. JT_LdvCountingProcessor)
   * @return String The operation id (JT_LDV_Checkpoint__c.JT_OperationId__c) to poll
   **/
  @AuraEnabled
  public static String startLdvBulkOperation(
    String devName,
    String bindingsJson,
    Integer batchSize,
    String processorClassName
  ) {
    try {
      Map<String, Object> bindings = deserializeBindings(bindingsJson);
      JT_LDV_Checkpoint__c checkpoint = JT_DataSelector.startCursorOperation(
        devName,
        bindings,
        true,
        batchSize,
        processorClassName
      );
      System.enqueueJob(new JT_LdvCursorQueueable(checkpoint.Id));
      return checkpoint.JT_OperationId__c;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  /**
   * @description Polls the current progress of a chained LDV operation started via
   * startLdvBulkOperation.
   * @author Jaime Terrats
   * @param operationId The operation id returned by startLdvBulkOperation
   * @return LdvOperationStatus Current checkpoint status/progress
   **/
  @AuraEnabled
  public static LdvOperationStatus getLdvOperationStatus(String operationId) {
    List<JT_LDV_Checkpoint__c> checkpoints = [
      SELECT
        JT_Status__c,
        JT_CursorPosition__c,
        JT_RecordsProcessed__c,
        JT_TotalRecordCount__c,
        JT_LastError__c
      FROM JT_LDV_Checkpoint__c
      WHERE JT_OperationId__c = :operationId
      WITH USER_MODE
      LIMIT 1
    ];

    if (checkpoints.isEmpty()) {
      throw new AuraHandledException(
        'No LDV operation found for the given operation id.'
      );
    }

    JT_LDV_Checkpoint__c checkpoint = checkpoints[0];
    LdvOperationStatus status = new LdvOperationStatus();
    status.status = checkpoint.JT_Status__c;
    status.recordsProcessed = (Integer) checkpoint.JT_RecordsProcessed__c;
    status.totalRecordCount = (Integer) checkpoint.JT_TotalRecordCount__c;
    status.lastError = checkpoint.JT_LastError__c;
    return status;
  }

  /**
   * @description Cooperatively cancels a chained LDV operation. The currently-executing chunk
   * still finishes; the next chunk observes the Aborted status and stops the chain instead of
   * re-enqueueing (see JT_LdvCursorQueueable).
   * @author Jaime Terrats
   * @param operationId The operation id returned by startLdvBulkOperation
   **/
  @AuraEnabled
  public static void cancelLdvOperation(String operationId) {
    List<JT_LDV_Checkpoint__c> checkpoints = [
      SELECT Id, JT_Status__c
      FROM JT_LDV_Checkpoint__c
      WHERE JT_OperationId__c = :operationId
      WITH USER_MODE
      LIMIT 1
    ];

    if (checkpoints.isEmpty()) {
      throw new AuraHandledException(
        'No LDV operation found for the given operation id.'
      );
    }

    JT_LDV_Checkpoint__c checkpoint = checkpoints[0];
    if (
      checkpoint.JT_Status__c == 'Completed' ||
      checkpoint.JT_Status__c == 'Failed'
    ) {
      return;
    }

    checkpoint.JT_Status__c = 'Aborted';
    Database.update(checkpoint, AccessLevel.SYSTEM_MODE);
  }

  /**
   * @description Progress snapshot for a chained LDV operation, returned by
   * getLdvOperationStatus.
   **/
  public class LdvOperationStatus {
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer recordsProcessed;
    @AuraEnabled
    public Integer totalRecordCount;
    @AuraEnabled
    public String lastError;
  }

  /**
   * @description Helper to check if required parameters are empty
   * @param bindings Map of parameter bindings
   * @return Boolean True if all bindings are empty
   **/
  private static Boolean hasEmptyRequiredParameters(
    Map<String, Object> bindings
  ) {
    if (bindings == null || bindings.isEmpty()) {
      return true;
    }

    for (Object value : bindings.values()) {
      if (value != null && String.valueOf(value).trim() != '') {
        return false; // At least one parameter has a value
      }
    }

    return true; // All parameters are empty
  }

  /**
   * @description Inner class to collect records from cursor processing
   * Implements CursorProcessor interface from JT_DataSelector
   **/
  public class ResultCollector implements JT_DataSelector.CursorProcessor {
    private List<SObject> collectedRecords = new List<SObject>();

    public void processBatch(List<SObject> batch) {
      collectedRecords.addAll(batch);
    }

    public List<SObject> getAllRecords() {
      return collectedRecords;
    }
  }

  /**
   * @description Wrapper class for query risk assessment
   **/
  public class QueryRiskAssessment {
    @AuraEnabled
    public Integer estimatedRecordCount;
    @AuraEnabled
    public Boolean isHighRisk;
    @AuraEnabled
    public Boolean isCriticalRisk;
    @AuraEnabled
    public Boolean recommendBatchProcessing;
    @AuraEnabled
    public Boolean hasEmptyParameters;
    @AuraEnabled
    public String riskLevel; // LOW, MEDIUM, HIGH, CRITICAL, UNKNOWN
    @AuraEnabled
    public String message;
  }

  /**
   * @description Sets assessment to LOW risk for queries with child relationships
   * @param assessment Risk assessment to update
   * @param message Message to set
   */
  private static void setLowRiskAssessment(
    final QueryRiskAssessment assessment,
    final String message
  ) {
    assessment.isHighRisk = false;
    assessment.isCriticalRisk = false;
    assessment.recommendBatchProcessing = false;
    assessment.riskLevel = 'LOW';
    assessment.message = message;
  }

  /**
   * @description Assesses risk based on estimated record count
   * @param assessment Risk assessment to update
   * @param estimatedCount Estimated number of records
   */
  private static void assessRiskByCount(
    final QueryRiskAssessment assessment,
    final Integer estimatedCount
  ) {
    assessment.isHighRisk = estimatedCount > 10000;
    assessment.isCriticalRisk = estimatedCount > 50000;
    assessment.recommendBatchProcessing = estimatedCount > 5000;

    if (assessment.isCriticalRisk) {
      assessment.riskLevel = Label.JT_QueryViewerController_riskLevelCritical;
      assessment.message = Label.JT_QueryViewerController_queryExceedsLimit;
    } else if (assessment.isHighRisk) {
      assessment.riskLevel = Label.JT_QueryViewerController_riskLevelHigh;
      assessment.message = String.format(
        Label.JT_QueryViewerController_queryMayReturnLarge,
        new List<String>{ String.valueOf(estimatedCount) }
      );
    } else if (assessment.recommendBatchProcessing) {
      assessment.riskLevel = Label.JT_QueryViewerController_riskLevelMedium;
      assessment.message = String.format(
        Label.JT_QueryViewerController_queryWillReturn,
        new List<String>{ String.valueOf(estimatedCount) }
      );
    } else {
      assessment.riskLevel = 'LOW';
      assessment.message = String.format(
        Label.JT_QueryViewerController_queryIsSafeToExecute,
        new List<String>{ String.valueOf(estimatedCount) }
      );
    }
  }

  /**
   * @description Gets configuration with base query only
   * Centralizes config queries to avoid duplication
   * @param devName Configuration developer name
   * @return JT_DynamicQueryConfiguration__mdt Configuration record
   **/
  private static JT_DynamicQueryConfiguration__mdt getConfig(String devName) {
    List<JT_DynamicQueryConfiguration__mdt> configs = [
      SELECT JT_BaseQuery__c
      FROM JT_DynamicQueryConfiguration__mdt
      WHERE DeveloperName = :devName
      WITH USER_MODE
      LIMIT 1
    ];
    return configs.isEmpty() ? null : configs[0];
  }

  /**
   * @description Gets configuration with base query and object name
   * Centralizes config queries to avoid duplication
   * @param devName Configuration developer name
   * @return JT_DynamicQueryConfiguration__mdt Configuration record
   **/
  private static JT_DynamicQueryConfiguration__mdt getConfigWithObjectName(
    String devName
  ) {
    List<JT_DynamicQueryConfiguration__mdt> configs = [
      SELECT JT_BaseQuery__c, JT_ObjectName__c
      FROM JT_DynamicQueryConfiguration__mdt
      WHERE DeveloperName = :devName
      WITH USER_MODE
      LIMIT 1
    ];
    return configs.isEmpty() ? null : configs[0];
  }

  /**
   * @description Gets configuration with all fields (base query, object name, bindings)
   * Centralizes config queries to avoid duplication
   * @param devName Configuration developer name
   * @return JT_DynamicQueryConfiguration__mdt Configuration record
   **/
  private static JT_DynamicQueryConfiguration__mdt getConfigWithAllFields(
    String devName
  ) {
    List<JT_DynamicQueryConfiguration__mdt> configs = [
      SELECT JT_BaseQuery__c, JT_ObjectName__c, JT_Binding__c
      FROM JT_DynamicQueryConfiguration__mdt
      WHERE DeveloperName = :devName
      WITH USER_MODE
      LIMIT 1
    ];
    return configs.isEmpty() ? null : configs[0];
  }

  /**
   * @description Checks if any bind parameters are empty strings
   * @param bindings Map of bind parameters
   * @return Boolean True if any parameter is empty string
   */
  private static Boolean hasEmptyParameters(
    final Map<String, Object> bindings
  ) {
    if (bindings == null || bindings.isEmpty()) {
      return false;
    }

    for (Object value : bindings.values()) {
      if (value instanceof String && String.isBlank((String) value)) {
        return true;
      }
    }

    return false;
  }
}
