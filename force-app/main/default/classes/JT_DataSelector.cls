/**
 * @description Data Selector for dynamic SOQL queries with security enforcement
 * @author Jaime Terrats
 * @group Selector Layer
 * @last modified on 12-11-2025
 * @last modified by Jaime Terrats
 *
 * PMD Suppressions:
 * - CognitiveComplexity/CyclomaticComplexity: Inherent to bind variable processing and security checks
 * - AvoidBooleanMethodParameters: enforceSecurity flag is a common pattern for security-aware methods
 * - ExcessiveParameterList: All parameters are necessary for query execution flexibility
 * - AvoidDeeplyNestedIfStmts: Required for comprehensive bind variable validation
 **/
@SuppressWarnings(
  'PMD.CognitiveComplexity, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.AvoidBooleanMethodParameters, PMD.ExcessiveParameterList, PMD.AvoidDeeplyNestedIfStmts'
)
public inherited sharing class JT_DataSelector {
  /** Cache to store configurations and avoid repeated queries */
  private static Map<String, JT_DynamicQueryConfiguration__mdt> configCache = new Map<String, JT_DynamicQueryConfiguration__mdt>();

  /**
   * Platform Cache partition for this framework.
   * Ensures we don't collide with other applications' cached data.
   */
  private static final String CACHE_PARTITION = 'local.JTDynamicQueries';

  /** used to validate if there's already an instance of the class */
  private static JT_DataSelector instance;

  private static Cache.OrgPartition getPartition() {
    return Cache.Org.getPartition(CACHE_PARTITION);
  }

  @SuppressWarnings('PMD.EmptyStatementBlock')
  /**
   * @description class consturctor
   * @author Jaime Terrats | 06-18-2025
   **/
  private JT_DataSelector() {
    // doesn't require initialization
  }

  /**
   * @description create instance for singleton pattern design
   * @author Jaime Terrats | 06-18-2025
   * @return DataSelector
   **/
  public static JT_DataSelector getInstance() {
    if (instance == null) {
      instance = new JT_DataSelector();
    }
    return instance;
  }

  /**
   * @description Invocable method wrapper for Flow and Agentforce integration
   */
  public class InvocableRequest {
    @InvocableVariable(
      label='Configuration Name'
      description='The developer name of the query configuration'
      required=true
    )
    public String configName;

    @InvocableVariable(
      label='Binding Parameters (JSON)'
      description='Optional JSON string with bind variable values'
      required=false
    )
    public String bindingsJson;
  }

  /**
   * @description Invocable method result wrapper
   */
  public class InvocableResult {
    @InvocableVariable(
      label='Records'
      description='List of records returned by the query'
    )
    public List<SObject> records;

    @InvocableVariable(
      label='Record Count'
      description='Number of records returned'
    )
    public Integer recordCount;

    @InvocableVariable(
      label='Success'
      description='Whether the query executed successfully'
    )
    public Boolean success;

    @InvocableVariable(
      label='Error Message'
      description='Error message if query failed'
    )
    public String errorMessage;
  }

  /**
   * @description Invocable method for Flow and Agentforce integration
   * @param requests List of invocable requests
   * @return List<InvocableResult> Results for each request
   */
  @InvocableMethod(
    label='Execute Dynamic Query'
    description='Execute a pre-configured SOQL query with optional bind parameters'
    category='Data'
    iconName='slds:standard:record_lookup'
  )
  public static List<InvocableResult> executeQuery(
    List<InvocableRequest> requests
  ) {
    List<InvocableResult> results = new List<InvocableResult>();

    for (InvocableRequest request : requests) {
      InvocableResult result = new InvocableResult();
      result.success = false;

      try {
        List<SObject> records;

        if (String.isNotBlank(request.bindingsJson)) {
          // Execute with bindings
          Map<String, Object> bindings = (Map<String, Object>) JSON.deserializeUntyped(
            request.bindingsJson
          );
          records = getRecords(request.configName, true, bindings);
        } else {
          // Execute without bindings
          records = getRecords(request.configName, true);
        }

        result.records = records;
        result.recordCount = records != null ? records.size() : 0;
        result.success = true;
      } catch (Exception e) {
        result.errorMessage = e.getMessage();
        result.records = new List<SObject>();
        result.recordCount = 0;
      }

      results.add(result);
    }

    return results;
  }

  /**
   * @description Gets bindings from configuration JSON string
   * Centralizes bindings deserialization to avoid duplication
   * @param config Configuration record with JT_Binding__c field
   * @return Map<String, Object> Deserialized bindings, or empty map if blank
   **/
  private static Map<String, Object> getConfigBindings(
    JT_DynamicQueryConfiguration__mdt config
  ) {
    return String.isNotBlank(config.JT_Binding__c)
      ? (Map<String, Object>) JSON.deserializeUntyped(config.JT_Binding__c)
      : new Map<String, Object>();
  }

  /**
   * @description Merges config bindings with custom bindings
   * Centralizes bindings merge logic to avoid duplication
   * @param configBindings Bindings from configuration
   * @param customBindings Custom bindings to merge
   * @return Map<String, Object> Merged bindings map
   **/
  private static Map<String, Object> mergeBindings(
    Map<String, Object> configBindings,
    Map<String, Object> customBindings
  ) {
    Map<String, Object> merged = new Map<String, Object>(configBindings);
    if (customBindings != null) {
      merged.putAll(customBindings);
    }
    return merged;
  }

  /**
   * @description Gets AccessLevel based on enforceSecurity flag
   * Centralizes access level determination to avoid duplication
   * @param enforceSecurity Whether to enforce security (USER_MODE vs SYSTEM_MODE)
   * @return AccessLevel USER_MODE if enforceSecurity is true, SYSTEM_MODE otherwise
   **/
  private static AccessLevel getAccessLevel(Boolean enforceSecurity) {
    return enforceSecurity ? AccessLevel.USER_MODE : AccessLevel.SYSTEM_MODE;
  }

  /**
   * @description Returns a configuration's base SOQL for callers outside this class that only
   * need the query text - e.g. JT_LdvCursorQueueable re-opening a Database.Cursor for a chunk
   * of a chained LDV operation it did not originally start.
   * @param devName Configuration developer name
   * @return String The configuration's JT_BaseQuery__c
   */
  public static String getBaseQuery(String devName) {
    return JT_DataSelector.getInstance().getConfig(devName).JT_BaseQuery__c;
  }

  /**
   * @description instance method to get the config with caching optimization
   * @param devName
   * @author Jaime Terrats | 06-18-2025
   * @return JT_DynamicQueryConfiguration__mdt
   **/
  private JT_DynamicQueryConfiguration__mdt getConfig(String devName) {
    // Check cache first to avoid unnecessary queries
    if (configCache.containsKey(devName)) {
      return configCache.get(devName);
    }

    // Platform Cache keys must be strictly alphanumeric.
    // Reuse the existing key sanitization rules from JT_ToolingApiUtil.
    final String sanitizedDevName = JT_ToolingApiUtil.toAlphanumeric(devName);

    // If devName cannot be converted into a valid alphanumeric key, skip Platform Cache.
    // Functional behavior remains unchanged: we still read from MDT and populate static cache.
    if (String.isBlank(sanitizedDevName)) {
      JT_DynamicQueryConfiguration__mdt config = getConfigFromMetadata(devName);
      configCache.put(devName, config);
      return config;
    }

    // Check Platform Cache (cross-transaction)
    // NOTE: Keys are intentionally stable so the UI "Clear Cache" can remove them.
    final String cacheKey = 'Config' + sanitizedDevName;
    JT_DynamicQueryConfiguration__mdt cachedConfig = (JT_DynamicQueryConfiguration__mdt) getPartition()
      .get(cacheKey);
    if (cachedConfig != null) {
      configCache.put(devName, cachedConfig);
      return cachedConfig;
    }
    JT_DynamicQueryConfiguration__mdt config = getConfigFromMetadata(devName);
    configCache.put(devName, config);
    getPartition().put(cacheKey, config);
    return config;
  }

  /**
   * Generates a strictly alphanumeric cache key suffix.
   */
  /**
   * Fetches configuration from MDT with security checks.
   * Isolated so Platform Cache failures do not change the functional behavior.
   */
  private JT_DynamicQueryConfiguration__mdt getConfigFromMetadata(
    String devName
  ) {
    if (!Schema.SObjectType.JT_DynamicQueryConfiguration__mdt.isAccessible()) {
      throw new AuraHandledException(
        Label.JT_DataSelector_insufficientPermissionsMetadata
      );
    }

    List<JT_DynamicQueryConfiguration__mdt> configs = [
      SELECT JT_BaseQuery__c, JT_Binding__c
      FROM JT_DynamicQueryConfiguration__mdt
      WHERE DeveloperName = :devName
      WITH USER_MODE
      LIMIT 1
    ];

    if (configs.isEmpty()) {
      throw new AuraHandledException(
        String.format(
          Label.JT_DataSelector_configurationNotFound,
          new List<String>{ devName }
        )
      );
    }

    return configs[0];
  }

  /**
   * @description returns a collection of records based on the configuration name provided
   * @author Jaime Terrats | 06-18-2025
   * @param devName
   * @param enforceSecurity
   * @return List<SObject>
   **/
  public static List<SObject> getRecords(
    String devName,
    Boolean enforceSecurity
  ) {
    final JT_DataSelector selectorInstance = JT_DataSelector.getInstance();
    final JT_DynamicQueryConfiguration__mdt config = selectorInstance.getConfig(
      devName
    );

    // Check if query uses unsupported operators and throw descriptive error
    validateSupportedOperators(config.JT_BaseQuery__c);

    // Deserialize bindings only once
    Map<String, Object> bindings = getConfigBindings(config);

    // Use appropriate access level
    AccessLevel accessMode = getAccessLevel(enforceSecurity);

    return Database.queryWithBinds(
      config.JT_BaseQuery__c,
      bindings,
      accessMode
    );
  }

  /**
   * @description Validates query doesn't use operators not supported by Salesforce SOQL
   * @param query SOQL query string to validate
   * @throws UnsupportedOperatorException If unsupported operators are detected
   */
  @TestVisible
  private static void validateSupportedOperators(String query) {
    if (String.isBlank(query)) {
      return;
    }

    String normalizedQuery = query.toLowerCase();

    // Check for BETWEEN operator
    if (normalizedQuery.contains(' between ')) {
      throw new UnsupportedOperatorException(
        System.Label.JT_Error_BetweenOperatorNotSupported
      );
    }

    // Check for NOT LIKE operator
    if (normalizedQuery.contains(' not like ')) {
      throw new UnsupportedOperatorException(
        System.Label.JT_Error_NotLikeOperatorNotSupported
      );
    }

    // Check for HAVING clause
    if (normalizedQuery.contains(' having ')) {
      throw new UnsupportedOperatorException(
        System.Label.JT_Error_HavingClauseNotSupported
      );
    }
  }

  /**
   * @description Custom exception for unsupported SOQL operators
   */
  public class UnsupportedOperatorException extends Exception {
  }

  /**
   * @description Validates and converts binding types by detecting operators in query
   * @param bindings Raw bindings from user input
   * @param query SOQL query string to analyze for operators
   * @return Map<String, Object> Validated and converted bindings
   */
  @TestVisible
  private static Map<String, Object> validateAndConvertBindings(
    Map<String, Object> bindings,
    String query
  ) {
    if (bindings == null || bindings.isEmpty()) {
      return bindings;
    }

    if (String.isBlank(query)) {
      return bindings;
    }

    Map<String, Object> validatedBindings = new Map<String, Object>();

    // Decode HTML entities that may come from metadata (e.g., &gt;= becomes >=, &lt;= becomes <=)
    String decodedQuery = query.replace('&gt;', '>')
      .replace('&lt;', '<')
      .replace('&amp;', '&');
    String normalizedQuery = decodedQuery.toLowerCase();

    for (String key : bindings.keySet()) {
      Object value = bindings.get(key);

      String bindingPattern = ':' + key.toLowerCase();

      // Check if used with IN/NOT IN/INCLUDES/EXCLUDES (requires List)
      // Allow for optional spaces around the colon: " in :param", " in:param", " in : param"
      Pattern inPattern = Pattern.compile(
        '\\bin\\s*' + Pattern.quote(bindingPattern) + '\\b'
      );
      Pattern notInPattern = Pattern.compile(
        '\\bnot\\s+in\\s*' + Pattern.quote(bindingPattern) + '\\b'
      );
      Pattern includesPattern = Pattern.compile(
        '\\bincludes\\s*' + Pattern.quote(bindingPattern) + '\\b'
      );
      Pattern excludesPattern = Pattern.compile(
        '\\bexcludes\\s*' + Pattern.quote(bindingPattern) + '\\b'
      );

      Boolean requiresList =
        inPattern.matcher(normalizedQuery).find() ||
        notInPattern.matcher(normalizedQuery).find() ||
        includesPattern.matcher(normalizedQuery).find() ||
        excludesPattern.matcher(normalizedQuery).find();

      if (requiresList) {
        if (!(value instanceof List<Object>)) {
          final String valueType = getValueTypeName(value);
          throw new IllegalArgumentException(
            String.format(
              'Binding "{0}" requires a List for IN/NOT IN/INCLUDES/EXCLUDES operators, but received {1}',
              new List<String>{ key, valueType }
            )
          );
        }
        validatedBindings.put(
          key,
          convertListToTypedList((List<Object>) value)
        );
      } else {
        // Check if used in numeric comparison operators (>=, <=, >, <, =, !=)
        Object convertedValue = convertNumericBindingValue(
          decodedQuery,
          key,
          value
        );

        // Check for date/datetime comparisons and convert ISO strings
        convertedValue = convertDateBindingValue(
          decodedQuery,
          key,
          convertedValue
        );

        validatedBindings.put(key, convertedValue);
      }
    }

    return validatedBindings;
  }

  /**
   * @description Converts binding value to appropriate type based on query context
   * Detects numeric comparisons and converts Decimal to Integer when field type requires it
   * JavaScript already sends typed values (parseInt/parseFloat), so we only need to handle
   * Decimal -> Integer conversion based on field type
   * @param query The SOQL query string
   * @param bindingKey The binding variable name
   * @param value The binding value (may be Decimal from JSON deserialization or String for legacy)
   * @return Object Converted value with appropriate type
   */
  @TestVisible
  private static Object convertNumericBindingValue(
    String query,
    String bindingKey,
    Object value
  ) {
    if (value == null) {
      return value;
    }

    // If value is already Integer, no conversion needed
    if (value instanceof Integer) {
      return value;
    }

    // Check if this is a numeric comparison
    String bindingPattern = ':' + bindingKey;
    String normalizedQuery = query.toLowerCase();
    Boolean isNumericComparison = false;
    String escapedPattern = Pattern.quote(bindingPattern);

    // Pattern 1: Field >= :binding or Field <= :binding or Field > :binding or Field < :binding
    Pattern pattern1 = Pattern.compile(
      '(?i)(?s)[a-z0-9_]+\\s+[>=<]+\\s*' + escapedPattern + '\\b'
    );
    Matcher matcher1 = pattern1.matcher(normalizedQuery);
    if (matcher1.find()) {
      isNumericComparison = true;
    }

    // Pattern 2: :binding >= Field or :binding <= Field or :binding > Field or :binding < Field
    if (!isNumericComparison) {
      Pattern pattern2 = Pattern.compile(
        '(?i)(?s)\\b' + escapedPattern + '\\s*[>=<]+\\s+[a-z0-9_]+'
      );
      Matcher matcher2 = pattern2.matcher(normalizedQuery);
      if (matcher2.find()) {
        isNumericComparison = true;
      }
    }

    // Pattern 3: Field = :binding or Field != :binding (only if value is numeric)
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
        // Check if value is numeric (Decimal or numeric String)
        if (value instanceof Decimal || value instanceof Integer) {
          isNumericComparison = true;
        } else if (value instanceof String) {
          String stringValue = ((String) value).trim().replace(',', '');
          if (isNumericString(stringValue)) {
            isNumericComparison = true;
          }
        }
      }
    }

    if (!isNumericComparison) {
      return value;
    }

    // Handle Decimal -> Integer conversion based on field type
    if (value instanceof Decimal) {
      Boolean isIntegerField = isIntegerFieldBinding(query, bindingKey);
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
        Boolean isIntegerField = isIntegerFieldBinding(query, bindingKey);
        if (isIntegerField) {
          return Integer.valueOf(stringValue);
        } else {
          return Decimal.valueOf(stringValue);
        }
      } catch (Exception e) {
        return value;
      }
    }

    return value;
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
    String escapedPattern = Pattern.quote(bindingPattern);

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
   * @description Converts ISO date/datetime strings to Date/Datetime objects
   * Detects if binding is used with Date or Datetime fields and converts ISO strings accordingly
   * @param query The SOQL query string
   * @param bindingKey The binding variable name
   * @param value The binding value (may be ISO string from JavaScript)
   * @return Object Converted Date or Datetime, or original value if not a date/datetime binding
   */
  @TestVisible
  private static Object convertDateBindingValue(
    String query,
    String bindingKey,
    Object value
  ) {
    if (value == null || !(value instanceof String)) {
      return value;
    }

    String stringValue = ((String) value).trim();
    if (String.isBlank(stringValue)) {
      return value;
    }

    Boolean isDateComparison = isDateFieldBinding(query, bindingKey);
    Boolean isDatetimeComparison = isDatetimeFieldBinding(query, bindingKey);

    if (!isDateComparison && !isDatetimeComparison) {
      return value;
    }

    try {
      if (isDatetimeComparison) {
        // Convert ISO string to Datetime
        // JavaScript toISOString() format: "2024-01-15T10:30:00.000Z" or "2024-01-15T10:30:00Z"
        // DateTime.ValueofGmt() expects: "yyyy-MM-dd HH:mm:ss" in GMT
        String normalizedDate = stringValue;
        // Remove timezone offset if present (+HH:mm or -HH:mm)
        normalizedDate = normalizedDate.replaceAll('[+-]\\d{2}:\\d{2}$', '');
        // Replace 'T' with space (required for ValueofGmt)
        normalizedDate = normalizedDate.replace('T', ' ');
        // Remove 'Z' at the end
        normalizedDate = normalizedDate.replace('Z', '');
        // Remove milliseconds if present (.000) - must be at the end after removing Z
        normalizedDate = normalizedDate.replaceAll('\\.\\d{1,3}$', '');
        // Trim any trailing spaces
        normalizedDate = normalizedDate.trim();
        // Parse to Datetime using ValueofGmt
        return DateTime.ValueofGmt(normalizedDate);
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
    String escapedPattern = Pattern.quote(bindingPattern);

    // Common Date field names in Salesforce
    List<String> dateFieldNames = new List<String>{
      'closedate',
      'startdate',
      'enddate',
      'duedate',
      'activitydate',
      'date'
    };

    // Check if binding is used with any Date field
    for (String fieldName : dateFieldNames) {
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
    String escapedPattern = Pattern.quote(bindingPattern);

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
   * @description Gets the type name of a value for error messages
   * @param value Value to get type name for
   * @return String Type name
   */
  @TestVisible
  private static String getValueTypeName(Object value) {
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
    return 'Object';
  }

  /**
   * @description Converts List<Object> to properly typed list for Database.queryWithBinds
   * Automatically detects the type based on the first non-null element
   * @param values List of values to convert
   * @return Object Typed list (List<String>, List<Integer>, List<Decimal>, etc.)
   */
  @TestVisible
  private static Object convertListToTypedList(List<Object> values) {
    if (values == null) {
      return new List<String>(); // Return empty List<String> instead of null
    }
    if (values.isEmpty()) {
      return new List<String>(); // Return empty List<String> instead of List<Object>
    }

    // Find first non-null element to determine type
    Object firstNonNull = null;
    for (Object val : values) {
      if (val != null) {
        firstNonNull = val;
        break;
      }
    }

    // If all elements are null, return as List<String> (safest default)
    if (firstNonNull == null) {
      return convertToStringList(values);
    }

    // Detect type from first non-null element
    // Note: JSON deserialized values from JavaScript may not be recognized by instanceof
    // For IN/NOT IN operators with String columns, we default to List<String>
    // unless we can definitively prove the type is something else

    // First check for explicit types (from Apex code, not JSON)
    if (firstNonNull instanceof Integer) {
      return convertToIntegerList(values);
    }
    if (firstNonNull instanceof Decimal) {
      return convertToDecimalList(values);
    }
    if (firstNonNull instanceof Date) {
      return convertToDateList(values);
    }
    if (firstNonNull instanceof Datetime) {
      return convertToDatetimeList(values);
    }
    if (firstNonNull instanceof String || firstNonNull instanceof Id) {
      return convertToStringList(values);
    }

    // For JSON-deserialized values, try to determine type by attempting conversion
    // Check if all values can be converted to Integer (must be ALL integers)
    Boolean allIntegers = true;
    for (Object val : values) {
      if (val != null) {
        try {
          Integer.valueOf(String.valueOf(val));
        } catch (Exception e) {
          allIntegers = false;
          break;
        }
      }
    }
    if (allIntegers && values.size() > 0) {
      return convertToIntegerList(values);
    }

    // Check if all values can be converted to Decimal (must be ALL decimals)
    Boolean allDecimals = true;
    for (Object val : values) {
      if (val != null) {
        try {
          Decimal.valueOf(String.valueOf(val));
        } catch (Exception e) {
          allDecimals = false;
          break;
        }
      }
    }
    if (allDecimals && values.size() > 0) {
      return convertToDecimalList(values);
    }

    // Default: return as List<String> (safest for most cases, especially for JSON-deserialized values)
    // This handles cases where JSON deserializes strings as generic objects
    // String.valueOf() will handle the conversion properly
    // For IN/NOT IN operators with String columns, this is the correct type
    return convertToStringList(values);
  }

  /**
   * @description Converts List<Object> to List<Date>
   * @param values List of values to convert
   * @return List<Date> Converted list
   */
  @TestVisible
  private static List<Date> convertToDateList(List<Object> values) {
    List<Date> typedList = new List<Date>();
    for (Object val : values) {
      if (val instanceof Date) {
        typedList.add((Date) val);
      } else {
        typedList.add(Date.valueOf(String.valueOf(val)));
      }
    }
    return typedList;
  }

  /**
   * @description Converts List<Object> to List<Datetime>
   * @param values List of values to convert
   * @return List<Datetime> Converted list
   */
  @TestVisible
  private static List<Datetime> convertToDatetimeList(List<Object> values) {
    List<Datetime> typedList = new List<Datetime>();
    for (Object val : values) {
      if (val instanceof Datetime) {
        typedList.add((Datetime) val);
      } else {
        typedList.add(Datetime.valueOf(String.valueOf(val)));
      }
    }
    return typedList;
  }

  /**
   * @description Converts List<Object> to List<String>
   * @param values List of values to convert
   * @return List<String> Converted list
   */
  @TestVisible
  private static List<String> convertToStringList(List<Object> values) {
    List<String> typedList = new List<String>();
    for (Object val : values) {
      if (val == null) {
        typedList.add(null);
      } else if (val instanceof String) {
        typedList.add((String) val);
      } else if (val instanceof Id) {
        typedList.add((String) val);
      } else {
        // For JSON-deserialized values that don't pass instanceof checks,
        // String.valueOf() will convert them to strings
        String strValue = String.valueOf(val);
        typedList.add(strValue);
      }
    }
    return typedList;
  }

  /**
   * @description Converts List<Object> to List<Integer>
   * @param values List of values to convert
   * @return List<Integer> Converted list
   */
  @TestVisible
  private static List<Integer> convertToIntegerList(List<Object> values) {
    List<Integer> typedList = new List<Integer>();
    for (Object val : values) {
      if (val instanceof Integer) {
        typedList.add((Integer) val);
      } else {
        typedList.add(Integer.valueOf(String.valueOf(val)));
      }
    }
    return typedList;
  }

  /**
   * @description Converts List<Object> to List<Decimal>
   * @param values List of values to convert
   * @return List<Decimal> Converted list
   */
  @TestVisible
  private static List<Decimal> convertToDecimalList(List<Object> values) {
    List<Decimal> typedList = new List<Decimal>();
    for (Object val : values) {
      if (val instanceof Decimal) {
        typedList.add((Decimal) val);
      } else {
        typedList.add(Decimal.valueOf(String.valueOf(val)));
      }
    }
    return typedList;
  }

  /**
   * @description Process large query results using a real Apex Database.Cursor,
   * fetched in bounded chunks and tracked via a JT_LDV_Checkpoint__c row.
   * Still invoked synchronously in a single transaction - multi-transaction chaining and
   * resumption is handled separately by JT_LdvCursorQueueable.
   * @param params CursorProcessingParams object containing all parameters
   * @return Integer Total number of records processed
   * @see https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_SOQL_cursors.htm
   */
  public static Integer processRecordsWithCursor(
    CursorProcessingParams params
  ) {
    final JT_DataSelector selectorInstance = JT_DataSelector.getInstance();
    final JT_DynamicQueryConfiguration__mdt config = selectorInstance.getConfig(
      params.devName
    );

    Map<String, Object> configBindings = getConfigBindings(config);
    Map<String, Object> mergedBindings = mergeBindings(
      configBindings,
      params.bindings
    );

    AccessLevel accessMode = getAccessLevel(params.enforceSecurity);

    Integer effectiveBatchSize = params.batchSize != null &&
      params.batchSize > 0
      ? params.batchSize
      : 200;

    JT_LDV_Checkpoint__c checkpoint = new JT_LDV_Checkpoint__c(
      JT_OperationId__c = generateOperationId(),
      JT_ConfigDevName__c = params.devName,
      JT_ChunkSize__c = effectiveBatchSize,
      JT_CursorPosition__c = 0,
      JT_RecordsProcessed__c = 0,
      JT_Status__c = 'InProgress',
      JT_InitiatedBy__c = UserInfo.getUserId(),
      JT_StartedAt__c = System.now()
    );
    Database.insert(checkpoint, AccessLevel.SYSTEM_MODE);

    Integer totalProcessed = 0;
    try {
      Database.Cursor cursor = Database.getCursorWithBinds(
        config.JT_BaseQuery__c,
        mergedBindings,
        accessMode
      );
      Integer totalSize = cursor.getNumRecords();
      Integer position = 0;

      while (position < totalSize) {
        Integer fetchSize = Math.min(effectiveBatchSize, totalSize - position);
        List<SObject> batch = cursor.fetch(position, fetchSize);
        if (batch.isEmpty()) {
          break;
        }
        params.processor.processBatch(batch);
        totalProcessed += batch.size();
        position += batch.size();
      }

      checkpoint.JT_Status__c = 'Completed';
      checkpoint.JT_CursorPosition__c = position;
      checkpoint.JT_RecordsProcessed__c = totalProcessed;
      checkpoint.JT_TotalRecordCount__c = totalSize;
      checkpoint.JT_CompletedAt__c = System.now();
      Database.update(checkpoint, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
      checkpoint.JT_Status__c = 'Failed';
      checkpoint.JT_LastError__c = e.getTypeName() + ': ' + e.getMessage();
      Database.update(checkpoint, AccessLevel.SYSTEM_MODE);
      throw e;
    }

    return totalProcessed;
  }

  /**
   * @description Starts a chained, multi-transaction LDV cursor operation.
   * Persists a checkpoint and returns it WITHOUT fetching any records - JT_LdvCursorQueueable
   * performs the actual chunked fetch/processing, one bounded chunk per transaction.
   * @param devName Configuration developer name
   * @param bindings Custom bindings
   * @param enforceSecurity Whether chunks should query in USER_MODE (true) or SYSTEM_MODE (false)
   * @param batchSize Bounded fetch size per chunk (default 200)
   * @param processorTypeName Fully-qualified JT_DataSelector.CursorProcessor implementation with
   * a public no-arg constructor - re-instantiated once per chunk since instances cannot be
   * serialized across Queueable transactions
   * @return JT_LDV_Checkpoint__c The persisted checkpoint (status Pending, position 0)
   */
  public static JT_LDV_Checkpoint__c startCursorOperation(
    String devName,
    Map<String, Object> bindings,
    Boolean enforceSecurity,
    Integer batchSize,
    String processorTypeName
  ) {
    final JT_DataSelector selectorInstance = JT_DataSelector.getInstance();
    final JT_DynamicQueryConfiguration__mdt config = selectorInstance.getConfig(
      devName
    );

    Map<String, Object> configBindings = getConfigBindings(config);
    Map<String, Object> mergedBindings = mergeBindings(
      configBindings,
      bindings
    );

    AccessLevel accessMode = getAccessLevel(enforceSecurity);
    Integer effectiveBatchSize = batchSize != null &&
      batchSize > 0
      ? batchSize
      : 200;

    Database.Cursor cursor = Database.getCursorWithBinds(
      config.JT_BaseQuery__c,
      mergedBindings,
      accessMode
    );
    Integer totalSize = cursor.getNumRecords();

    Map<String, Object> persistedState = new Map<String, Object>{
      'bindings' => mergedBindings,
      'enforceSecurity' => enforceSecurity
    };

    JT_LDV_Checkpoint__c checkpoint = new JT_LDV_Checkpoint__c(
      JT_OperationId__c = generateOperationId(),
      JT_ConfigDevName__c = devName,
      JT_BindingsJson__c = JSON.serialize(persistedState),
      JT_ChunkSize__c = effectiveBatchSize,
      JT_CursorPosition__c = 0,
      JT_RecordsProcessed__c = 0,
      JT_TotalRecordCount__c = totalSize,
      JT_Status__c = 'Pending',
      JT_RetryCount__c = 0,
      JT_MaxRetries__c = 3,
      JT_ProcessorClass__c = processorTypeName,
      JT_InitiatedBy__c = UserInfo.getUserId(),
      JT_StartedAt__c = System.now()
    );
    Database.insert(checkpoint, AccessLevel.SYSTEM_MODE);
    return checkpoint;
  }

  /**
   * @description One bounded page of a real Database.Cursor, for forward pagination
   * ({first, after, hasNextPage, endCursor}) instead of loading a full result set client-side.
   */
  public class QueryPageResult {
    public List<SObject> records;
    public Boolean hasNextPage;
    public Integer nextPosition;
    public Integer totalRecordCount;
  }

  /**
   * @description Fetches one bounded page via a real Database.Cursor - the query is re-opened
   * fresh on every call (a Database.Cursor cannot be persisted across separate Apex
   * invocations), then bounded to exactly [position, position + pageSize).
   * @param devName Configuration developer name
   * @param bindings Custom bindings
   * @param enforceSecurity Whether to use USER_MODE
   * @param position Row offset to start this page at (0 for the first page)
   * @param pageSize Bounded page size (default 10)
   * @return QueryPageResult One page plus pagination metadata
   */
  public static QueryPageResult getRecordsPage(
    String devName,
    Map<String, Object> bindings,
    Boolean enforceSecurity,
    Integer position,
    Integer pageSize
  ) {
    final JT_DataSelector selectorInstance = JT_DataSelector.getInstance();
    final JT_DynamicQueryConfiguration__mdt config = selectorInstance.getConfig(
      devName
    );

    Map<String, Object> configBindings = getConfigBindings(config);
    Map<String, Object> mergedBindings = mergeBindings(
      configBindings,
      bindings
    );
    AccessLevel accessMode = getAccessLevel(enforceSecurity);

    Integer effectivePosition = position != null && position > 0
      ? position
      : 0;
    Integer effectivePageSize = pageSize != null && pageSize > 0
      ? pageSize
      : 10;

    Database.Cursor cursor = Database.getCursorWithBinds(
      config.JT_BaseQuery__c,
      mergedBindings,
      accessMode
    );
    Integer totalSize = cursor.getNumRecords();
    Integer fetchSize = Math.min(
      effectivePageSize,
      Math.max(0, totalSize - effectivePosition)
    );

    QueryPageResult result = new QueryPageResult();
    result.records = fetchSize > 0
      ? cursor.fetch(effectivePosition, fetchSize)
      : new List<SObject>();
    result.nextPosition = effectivePosition + result.records.size();
    result.hasNextPage = result.nextPosition < totalSize;
    result.totalRecordCount = totalSize;
    return result;
  }

  /**
   * @description Generates a UUID-v4-shaped operation id for JT_LDV_Checkpoint__c.JT_OperationId__c.
   * @return String 36-character hex-and-hyphen identifier
   */
  @TestVisible
  private static String generateOperationId() {
    String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    return hex.substring(0, 8) +
      '-' +
      hex.substring(8, 12) +
      '-' +
      hex.substring(12, 16) +
      '-' +
      hex.substring(16, 20) +
      '-' +
      hex.substring(20);
  }

  /**
   * @description Builds a dynamic SOQL query by removing WHERE conditions for empty/missing bindings
   * This ensures Database.queryWithBinds only receives bindings that exist in the query
   * @param baseQuery The original SOQL query string
   * @param bindings Map of binding variables
   * @return String Dynamic query with conditions removed for empty/missing bindings
   */
  @TestVisible
  private static String buildDynamicQuery(
    String baseQuery,
    Map<String, Object> bindings
  ) {
    if (String.isBlank(baseQuery)) {
      return baseQuery;
    }

    String result = baseQuery;

    // Find all bindings referenced in the query
    // Handle both "=:name" and "=: name" (with optional space after colon)
    Pattern bindingPattern = Pattern.compile(':\\s*(\\w+)\\b');
    Matcher matcher = bindingPattern.matcher(baseQuery);
    Set<String> referencedBindings = new Set<String>();
    while (matcher.find()) {
      referencedBindings.add(matcher.group(1));
    }

    // Remove conditions for bindings that don't exist or are empty
    for (String bindingKey : referencedBindings) {
      Boolean shouldRemove = false;

      if (bindings == null || !bindings.containsKey(bindingKey)) {
        shouldRemove = true;
      } else {
        Object value = bindings.get(bindingKey);
        Boolean isEmpty =
          value == null ||
          (value instanceof String && String.isBlank((String) value)) ||
          (value instanceof List<Object> && ((List<Object>) value).isEmpty());

        if (isEmpty) {
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
    // Handle both "=:name" and "=: name" (with optional space after colon)
    // Escape the colon and binding key, but allow optional space after colon
    String escapedBindingKey = Pattern.quote(bindingKey);
    String bindingPattern = ':\\s*' + escapedBindingKey;

    // Match condition with optional AND/OR before and after
    // Use negative lookahead to avoid capturing OR from ORDER BY
    // Pattern: (AND|OR)? Field (IN|NOT IN|...) :binding (AND|OR)?
    // But don't capture OR if it's part of ORDER BY
    Pattern conditionPattern = Pattern.compile(
      '(?i)(?s)(?:\\s+(?:AND|OR))?\\s+[a-z0-9_]+\\s+(?:IN|NOT\\s+IN|INCLUDES|EXCLUDES|[=<>!]+)\\s*' +
        bindingPattern +
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
   * @description Filters bindings map to only include bindings referenced in the query
   * This prevents "Key does not exist in bindMap" errors with Database.queryWithBinds
   * @param bindings Map of all bindings
   * @param query The SOQL query string
   * @return Map<String, Object> Filtered bindings map containing only referenced bindings
   */
  @TestVisible
  private static Map<String, Object> filterBindingsForQuery(
    Map<String, Object> bindings,
    String query
  ) {
    if (bindings == null || bindings.isEmpty() || String.isBlank(query)) {
      return bindings != null ? bindings : new Map<String, Object>();
    }

    // Find all bindings referenced in the query
    // Handle both "=:name" and "=: name" (with optional space after colon)
    Pattern bindingPattern = Pattern.compile(':\\s*(\\w+)\\b');
    Matcher matcher = bindingPattern.matcher(query);
    Set<String> referencedBindings = new Set<String>();
    while (matcher.find()) {
      referencedBindings.add(matcher.group(1));
    }

    // Filter bindings to only include referenced ones
    Map<String, Object> filteredBindings = new Map<String, Object>();
    for (String key : bindings.keySet()) {
      if (referencedBindings.contains(key)) {
        filteredBindings.put(key, bindings.get(key));
      }
    }

    return filteredBindings;
  }

  /**
   * @description Interface for cursor batch processing
   * Implement this interface to define custom processing logic for each batch
   */
  public interface CursorProcessor {
    /**
     * @description Process a batch of records
     * @param batch List of SObjects to process
     */
    void processBatch(List<SObject> batch);
  }

  /**
   * @description Parameter object for processRecordsWithCursor method
   * Follows project rule: no many parameters, always use objects
   */
  public class CursorProcessingParams {
    @AuraEnabled
    public String devName;
    @AuraEnabled
    public Map<String, Object> bindings;
    @AuraEnabled
    public Boolean enforceSecurity;
    @AuraEnabled
    public Integer batchSize;
    public CursorProcessor processor; // Not @AuraEnabled - interface cannot be serialized

    /**
     * @description Constructor with all parameters
     */
    public CursorProcessingParams(
      String devName,
      Map<String, Object> bindings,
      Boolean enforceSecurity,
      Integer batchSize,
      CursorProcessor processor
    ) {
      this.devName = devName;
      this.bindings = bindings;
      this.enforceSecurity = enforceSecurity;
      this.batchSize = batchSize;
      this.processor = processor;
    }
  }

  /**
   * @description Parameter object for getRecordsWithAutoStrategy method
   * Follows project rule: no many parameters, always use objects
   */
  public class AutoStrategyParams {
    @AuraEnabled
    public String devName;
    @AuraEnabled
    public Boolean enforceSecurity;
    @AuraEnabled
    public Map<String, Object> bindings;
    @AuraEnabled
    public Integer threshold;
    public CursorProcessor processor; // Not @AuraEnabled - interface cannot be serialized

    /**
     * @description Default constructor
     */
    public AutoStrategyParams() {
    }

    /**
     * @description Constructor with all parameters
     */
    public AutoStrategyParams(
      String devName,
      Boolean enforceSecurity,
      Map<String, Object> bindings,
      Integer threshold,
      CursorProcessor processor
    ) {
      this.devName = devName;
      this.enforceSecurity = enforceSecurity;
      this.bindings = bindings;
      this.threshold = threshold;
      this.processor = processor;
    }
  }

  /**
   * @description returns a collection of records based on the configuration name provided
   * @author Jaime Terrats | 06-18-2025
   * @param devName
   * @param enforceSecurity
   * @param bindings
   * @return List<SObject>
   **/
  public static List<SObject> getRecords(
    String devName,
    Boolean enforceSecurity,
    Map<String, Object> bindings
  ) {
    final JT_DataSelector selectorInstance = JT_DataSelector.getInstance();
    final JT_DynamicQueryConfiguration__mdt config = selectorInstance.getConfig(
      devName
    );

    // Check if query uses unsupported operators and throw descriptive error
    validateSupportedOperators(config.JT_BaseQuery__c);

    // Merge config bindings with custom bindings
    Map<String, Object> configBindings = getConfigBindings(config);
    Map<String, Object> mergedBindings = mergeBindings(
      configBindings,
      bindings
    );

    // Build dynamic query removing conditions for empty/missing bindings
    String dynamicQuery = buildDynamicQuery(
      config.JT_BaseQuery__c,
      mergedBindings
    );

    // Validate and convert bindings (auto-detect types from query patterns)
    // Only include bindings that are actually used in the dynamic query
    Map<String, Object> validatedBindings = validateAndConvertBindings(
      mergedBindings,
      dynamicQuery
    );

    // Filter bindings to only include those referenced in the dynamic query
    // CRITICAL: Use dynamicQuery (after buildDynamicQuery) not baseQuery
    // This ensures we only include bindings that are actually in the final query
    Map<String, Object> filteredBindings = filterBindingsForQuery(
      validatedBindings,
      dynamicQuery
    );

    // Use appropriate access level
    AccessLevel accessMode = getAccessLevel(enforceSecurity);

    // Final safety check: Ensure all bindings in filteredBindings are actually in dynamicQuery
    // This prevents "Key does not exist in bindMap" errors
    // Handle both "=:name" and "=: name" (with optional space after colon)
    Pattern bindingPattern = Pattern.compile(':\\s*(\\w+)\\b');
    Matcher matcher = bindingPattern.matcher(dynamicQuery);
    Set<String> finalReferencedBindings = new Set<String>();
    while (matcher.find()) {
      finalReferencedBindings.add(matcher.group(1));
    }

    // Remove any bindings that aren't actually in the final query
    Map<String, Object> finalBindings = new Map<String, Object>();
    for (String key : filteredBindings.keySet()) {
      if (finalReferencedBindings.contains(key)) {
        finalBindings.put(key, filteredBindings.get(key));
      }
    }

    return Database.queryWithBinds(dynamicQuery, finalBindings, accessMode);
  }

  /**
   * @description Count records for a given configuration
   * This method allows users to check record count BEFORE deciding execution strategy
   * Use this when you need to choose between standard query, cursor processing, or Batch/Queueable
   * @param devName Configuration name
   * @param bindings Custom bindings (merged with config bindings)
   * @param enforceSecurity Whether to use USER_MODE
   * @return Integer Number of records that would be returned
   * @example
   * // Check count first, then decide strategy
   * Integer count = JT_DataSelector.countRecordsForConfig('MyConfig', bindings, true);
   * if (count > 50000 && System.isBatch()) {
   *     // Use Batch Apex for async processing
   * } else if (count > 50000) {
   *     // Use cursor processing (sync only)
   *     JT_DataSelector.CursorProcessingParams params = new JT_DataSelector.CursorProcessingParams('MyConfig', bindings, true, 200, processor);
   *     JT_DataSelector.processRecordsWithCursor(params);
   * } else {
   *     // Use standard query
   *     List<SObject> records = JT_DataSelector.getRecords('MyConfig', true, bindings);
   * }
   */
  public static Integer countRecordsForConfig(
    String devName,
    Map<String, Object> bindings,
    Boolean enforceSecurity
  ) {
    final JT_DataSelector selectorInstance = JT_DataSelector.getInstance();
    final JT_DynamicQueryConfiguration__mdt config = selectorInstance.getConfig(
      devName
    );

    // Merge config bindings with custom bindings
    Map<String, Object> configBindings = getConfigBindings(config);
    Map<String, Object> mergedBindings = mergeBindings(
      configBindings,
      bindings
    );

    return countRecordsInternal(
      config.JT_BaseQuery__c,
      mergedBindings,
      enforceSecurity
    );
  }

  /**
   * @description Internal helper to count records for a given query
   * @param baseQuery The SOQL query to count
   * @param bindings Bind variables for the query
   * @param enforceSecurity Whether to use USER_MODE
   * @return Integer Number of records that would be returned
   */
  @TestVisible
  private static Integer countRecordsInternal(
    String baseQuery,
    Map<String, Object> bindings,
    Boolean enforceSecurity
  ) {
    // Build dynamic query removing conditions for empty/missing bindings
    // This ensures we only process bindings that are actually used in the query
    String dynamicQuery = buildDynamicQuery(baseQuery, bindings);

    // Convert SELECT query to COUNT query
    String countQuery = dynamicQuery.replaceAll(
      '(?i)SELECT[\\s\\S]+?FROM',
      'SELECT COUNT() FROM'
    );

    // Remove ORDER BY, LIMIT, OFFSET clauses for COUNT
    countQuery = countQuery.replaceAll('(?i)\\s+ORDER\\s+BY[^\\n]+', '');
    countQuery = countQuery.replaceAll('(?i)\\s+LIMIT\\s+\\d+', '');
    countQuery = countQuery.replaceAll('(?i)\\s+OFFSET\\s+\\d+', '');

    // Validate and convert bindings (auto-detect types from query patterns)
    // Only include bindings that are actually used in the dynamic query
    Map<String, Object> validatedBindings = validateAndConvertBindings(
      bindings,
      dynamicQuery
    );

    // Filter bindings to only include those referenced in the dynamic query
    // This prevents "Key does not exist in bindMap" errors
    Map<String, Object> filteredBindings = filterBindingsForQuery(
      validatedBindings,
      dynamicQuery
    );

    // Use appropriate access level
    AccessLevel accessMode = getAccessLevel(enforceSecurity);

    // Bind-safe: Database.countQueryWithBinds accepts the bind map directly, the same way
    // Database.queryWithBinds already works elsewhere in this class - no literal interpolation.
    return Database.countQueryWithBinds(
      countQuery,
      filteredBindings,
      accessMode
    );
  }

  /**
   * @description Smart method that automatically decides whether to use standard query
   * or cursor-based processing based on record count
   * WARNING: This method uses cursor processing for large datasets, which can ONLY be used
   * in synchronous contexts (NOT in @Future, Queueable, Batch, or Triggers).
   * For async contexts, use countRecordsForConfig() first, then decide your strategy.
   * @param params AutoStrategyParams object containing all parameters
   * @return List<SObject> Records if count <= threshold, empty list if cursor processing was used
   * @see countRecordsForConfig For checking count before deciding strategy in async contexts
   */
  public static List<SObject> getRecordsWithAutoStrategy(
    AutoStrategyParams params
  ) {
    String devName = params.devName;
    Boolean enforceSecurity = params.enforceSecurity;
    Map<String, Object> bindings = params.bindings;
    Integer threshold = params.threshold;
    CursorProcessor processor = params.processor;
    final JT_DataSelector selectorInstance = JT_DataSelector.getInstance();
    final JT_DynamicQueryConfiguration__mdt config = selectorInstance.getConfig(
      devName
    );

    // Merge config bindings with custom bindings
    Map<String, Object> configBindings = getConfigBindings(config);
    Map<String, Object> mergedBindings = mergeBindings(
      configBindings,
      bindings
    );

    // Set threshold (default 50,000)
    Integer effectiveThreshold = threshold != null &&
      threshold > 0
      ? threshold
      : 50000;

    // Step 1: Count records. A COUNT failure is evidence the query may be expensive or
    // unselective - it must never fall through to an unbounded getRecords() call. The caller
    // is required to handle JT_LdvRiskAssessmentException explicitly.
    Integer recordCount;
    try {
      recordCount = countRecordsInternal(
        config.JT_BaseQuery__c,
        mergedBindings,
        enforceSecurity
      );
    } catch (Exception e) {
      throw new JT_LdvRiskAssessmentException(
        'Unable to assess record count/risk for "' +
          devName +
          '": ' +
          e.getMessage()
      );
    }

    // Step 2: Decide strategy based on count
    if (recordCount > effectiveThreshold) {
      // Large result set - use cursor processing
      if (processor == null) {
        throw new AuraHandledException(
          String.format(
            Label.JT_DataSelector_queryWouldReturnRecords,
            new List<String>{
              String.valueOf(recordCount),
              String.valueOf(effectiveThreshold)
            }
          )
        );
      }

      // Process with cursor and return empty list (data is handled by processor)
      JT_DataSelector.CursorProcessingParams cursorParams = new JT_DataSelector.CursorProcessingParams(
        devName,
        mergedBindings,
        enforceSecurity,
        200,
        processor
      );
      processRecordsWithCursor(cursorParams);
      return new List<SObject>();
    } else {
      // Small/medium result set - use standard query
      return getRecords(devName, enforceSecurity, mergedBindings);
    }
  }

  /**
   * @description Overload with default threshold (50,000) and no processor
   * @param devName Configuration name
   * @param enforceSecurity Whether to use USER_MODE
   * @param bindings Custom bindings
   * @return List<SObject> Records if count <= 50000, throws exception if more
   */
  public static List<SObject> getRecordsWithAutoStrategy(
    String devName,
    Boolean enforceSecurity,
    Map<String, Object> bindings
  ) {
    AutoStrategyParams params = new AutoStrategyParams();
    params.devName = devName;
    params.enforceSecurity = enforceSecurity;
    params.bindings = bindings;
    params.threshold = 50000;
    params.processor = null;
    return getRecordsWithAutoStrategy(params);
  }
}
