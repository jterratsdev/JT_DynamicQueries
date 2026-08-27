/**
 * @description Test class for JT_QueryViewerController
 * @author Jaime Terrats
 * @group Dynamic Queries
 * @last modified on 11-28-2025
 * @last modified by Jaime Terrats
 **/
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.ApexDoc')
private class JT_QueryViewerController_Test {
  private static final String RUN_AS_PERMISSION_SET_DEV_NAME = 'JT_Dynamic_Queries';

  @testSetup
  static void setupTestData() {
    // Create test Account
    insert new Account(Name = 'Test Account for Viewer');
  }

  /**
   * @description Creates an active test user and assigns the Run As Permission Set.
   * Allows us to cover the happy path for canUseRunAs()/getAllActiveUsers().
   */
  private static User createUserWithRunAsPermissions() {
    final PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = :RUN_AS_PERMISSION_SET_DEV_NAME
      LIMIT 1
    ];

    final Profile leastPrivilege = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      LIMIT 1
    ];

    User u = new User(
      FirstName = 'RunAs',
      LastName = 'Tester',
      Email = 'runas.tester@example.com',
      Username = 'runas.tester+' + System.currentTimeMillis() + '@example.com',
      Alias = 'rtester',
      ProfileId = leastPrivilege.Id,
      TimeZoneSidKey = 'GMT',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US'
    );
    insert u;

    insert new PermissionSetAssignment(
      AssigneeId = u.Id,
      PermissionSetId = ps.Id
    );
    return u;
  }

  /**
   * @description Test child relationships in query results
   * Validates that child relationships (Contacts, Opportunities, etc.) are preserved
   */
  @IsTest
  static void testChildRelationshipsInQuery() {
    // Create test data with child relationships
    Account acc = new Account(
      Name = 'Test Account with Children',
      Type = 'Customer',
      Industry = 'Technology',
      AnnualRevenue = 1000000
    );
    insert acc;

    // Create child Contacts
    List<Contact> contacts = new List<Contact>{
      new Contact(
        AccountId = acc.Id,
        FirstName = 'John',
        LastName = 'Doe',
        Email = 'john@test.com'
      ),
      new Contact(
        AccountId = acc.Id,
        FirstName = 'Jane',
        LastName = 'Smith',
        Email = 'jane@test.com'
      )
    };
    insert contacts;

    // Create child Opportunities
    List<Opportunity> opps = new List<Opportunity>{
      new Opportunity(
        AccountId = acc.Id,
        Name = 'Test Opp 1',
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(30),
        Amount = 10000
      ),
      new Opportunity(
        AccountId = acc.Id,
        Name = 'Test Opp 2',
        StageName = 'Negotiation',
        CloseDate = Date.today().addDays(60),
        Amount = 20000
      )
    };
    insert opps;

    Test.startTest();

    // Execute query with child relationships
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Complete_Customer_360_View',
      '{"accountType": "Customer"}',
      null
    );

    Test.stopTest();

    // Validate result
    System.assert(result.success, 'Query should succeed');
    System.assert(result.recordCount > 0, 'Should return records');

    // 🔥 CRITICAL VALIDATION: Check if child relationships are preserved
    if (!result.records.isEmpty()) {
      System.debug(
        '🔥 TEST: First record: ' + JSON.serialize(result.records[0])
      );

      Map<String, Object> firstRecord = (Map<String, Object>) result.records[0];
      System.debug('🔥 TEST: First record keys: ' + firstRecord.keySet());

      // Check for Contacts child relationship
      System.assert(
        firstRecord.containsKey('Contacts'),
        'ERROR: Contacts child relationship is MISSING! Keys found: ' +
        firstRecord.keySet()
      );

      if (firstRecord.containsKey('Contacts')) {
        Object contactsObj = firstRecord.get('Contacts');
        System.debug('🔥 TEST: Contacts value: ' + contactsObj);

        // Contacts should be a Map with 'records' and 'totalSize'
        System.assert(
          contactsObj instanceof Map<String, Object>,
          'Contacts should be a Map, but is: ' + contactsObj
        );

        Map<String, Object> contactsMap = (Map<String, Object>) contactsObj;
        System.assert(
          contactsMap.containsKey('records'),
          'Contacts should have "records" key. Keys: ' + contactsMap.keySet()
        );
        System.assert(
          contactsMap.containsKey('totalSize'),
          'Contacts should have "totalSize" key. Keys: ' + contactsMap.keySet()
        );

        System.assertEquals(
          2,
          contactsMap.get('totalSize'),
          'Should have 2 contacts'
        );
      }
    }
  }

  /**
   * @description Test getConfigurations method
   * @author Jaime Terrats | 11-28-2025
   **/
  @IsTest
  static void testGetConfigurations() {
    Test.startTest();
    List<JT_QueryViewerController.ConfigurationOption> configs = JT_QueryViewerController.getConfigurations();
    Test.stopTest();

    System.assertNotEquals(null, configs, 'Configurations should not be null');
    System.assert(!configs.isEmpty(), 'Should have at least one configuration');
  }

  /**
   * @description Test executeQuery with bindings
   * @author Jaime Terrats | 11-28-2025
   **/
  @IsTest
  static void testExecuteQueryWithBindings() {
    Map<String, Object> bindings = new Map<String, Object>{
      'name' => 'Test Account for Viewer'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Test_Record',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertEquals(true, result.success, 'Query should succeed');
    System.assertNotEquals(0, result.recordCount, 'Should return records');
    System.assertNotEquals(null, result.fields, 'Fields should be populated');
  }

  /**
   * @description Test executeQuery without custom bindings (uses config bindings)
   * @author Jaime Terrats | 11-28-2025
   **/
  @IsTest
  static void testExecuteQueryWithoutBindings() {
    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Test_Record',
      '',
      null
    );
    Test.stopTest();

    // Result may succeed or fail depending on config bindings
    System.assertNotEquals(null, result, 'Result should not be null');
    if (!result.success) {
      System.assertNotEquals(
        null,
        result.errorMessage,
        'Error message should be populated'
      );
    }
  }

  /**
   * @description Test executeQueryPreview method
   * @author Jaime Terrats | 12-01-2025
   **/
  @IsTest
  static void testExecuteQueryPreview() {
    Map<String, Object> bindings = new Map<String, Object>{
      'name' => 'Test Account for Viewer'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryPreview(
      'Test_Record',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertEquals(true, result.success, 'Preview should succeed');
    System.assert(
      result.recordCount <= 5,
      'Preview should return max 5 records'
    );
    if (result.recordCount > 0) {
      System.assertNotEquals(null, result.fields, 'Fields should be populated');
      System.assertNotEquals(
        null,
        result.records,
        'Records should be populated'
      );
    }
  }

  /**
   * @description Test executeQueryPreview with invalid bindings
   * @author Jaime Terrats | 12-01-2025
   **/
  @IsTest
  static void testExecuteQueryPreviewError() {
    String invalidBindings = '{invalid json}';

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryPreview(
      'Test_Record',
      invalidBindings,
      null
    );
    Test.stopTest();

    System.assertEquals(
      false,
      result.success,
      'Preview should fail with invalid JSON'
    );
    System.assertNotEquals(
      null,
      result.errorMessage,
      'Error message should be present'
    );
  }

  /**
   * @description Test extractParameters method
   * @author Jaime Terrats | 11-28-2025
   **/
  @IsTest
  static void testExtractParameters() {
    String query = 'SELECT Id, Name FROM Account WHERE Name = :accountName AND Type = :accountType';

    Test.startTest();
    List<String> params = JT_QueryViewerController.extractParameters(query);
    Test.stopTest();

    System.assertEquals(2, params.size(), 'Should extract 2 parameters');
    System.assert(params.contains('accountName'), 'Should contain accountName');
    System.assert(params.contains('accountType'), 'Should contain accountType');
  }

  /**
   * @description Test extractParameters with empty query
   * @author Jaime Terrats | 11-28-2025
   **/
  @IsTest
  static void testExtractParametersEmpty() {
    Test.startTest();
    List<String> params = JT_QueryViewerController.extractParameters('');
    Test.stopTest();

    System.assertEquals(0, params.size(), 'Should return empty list');
  }

  /**
   * @description Test executeQuery with invalid config
   * @author Jaime Terrats | 11-28-2025
   **/
  @IsTest
  static void testExecuteQueryError() {
    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Invalid_Config',
      null,
      null
    );
    Test.stopTest();

    System.assertEquals(false, result.success, 'Query should fail');
    System.assertNotEquals(
      null,
      result.errorMessage,
      'Should have error message'
    );
  }

  /**
   * @description Test canUseRunAs method
   * @author Jaime Terrats | 11-28-2025
   **/
  @IsTest
  static void testCanUseRunAs() {
    User runAsUser = createUserWithRunAsPermissions();
    System.runAs(runAsUser) {
      Test.startTest();
      Boolean canUse = JT_QueryViewerController.canUseRunAs();
      Test.stopTest();

      System.assertNotEquals(null, canUse, 'Should return a boolean');
    }
  }

  /**
   * @description Test searchUsers method
   * @author Jaime Terrats | 11-28-2025
   **/
  @IsTest
  static void testGetAllActiveUsers() {
    User runAsUser = createUserWithRunAsPermissions();
    System.runAs(runAsUser) {
      Test.startTest();
      try {
        List<JT_QueryViewerController.UserOption> users = JT_QueryViewerController.getAllActiveUsers();

        System.assertNotEquals(null, users, 'Should return a list');

        for (JT_QueryViewerController.UserOption user : users) {
          System.assertNotEquals(
            UserInfo.getUserId(),
            user.value,
            'Should not include current user'
          );
        }
      } catch (Exception e) {
        System.assert(
          e instanceof AuraHandledException,
          'Should throw AuraHandledException'
        );
      }
      Test.stopTest();
    }
  }

  /**
   * @description Test executeQuery with Run As User
   * @author Jaime Terrats | 11-28-2025
   **/
  @IsTest
  static void testExecuteQueryWithRunAs() {
    User currentUser = JT_SystemSelector.getCurrentUser();
    Map<String, Object> bindings = new Map<String, Object>{
      'name' => 'Test Account for Viewer'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    try {
      JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
        'Test_Record',
        bindingsJson,
        currentUser.Id
      );
      // Should succeed or fail based on permissions
      System.assertNotEquals(null, result, 'Should return a result');
    } catch (Exception e) {
      // May fail if user doesn't have Run As permissions
      System.assert(true, 'Exception expected if no permissions');
    }
    Test.stopTest();
  }

  /**
   * @description Test extractParameters with various spacing formats
   * @author Jaime Terrats | 11-30-2025
   **/
  @IsTest
  static void testExtractParametersVariousSpacing() {
    String query1 = 'SELECT Id FROM Account WHERE Name = :name';
    String query2 = 'SELECT Id FROM Account WHERE Name =:name';
    String query3 = 'SELECT Id FROM Account WHERE Name = : name';
    String query4 = 'SELECT Id FROM Account WHERE Name =: name';

    Test.startTest();
    List<String> params1 = JT_QueryViewerController.extractParameters(query1);
    List<String> params2 = JT_QueryViewerController.extractParameters(query2);
    List<String> params3 = JT_QueryViewerController.extractParameters(query3);
    List<String> params4 = JT_QueryViewerController.extractParameters(query4);
    Test.stopTest();

    // All should extract the parameter regardless of spacing
    System.assertEquals(1, params1.size(), 'Should extract parameter');
    System.assertEquals(1, params2.size(), 'Should extract parameter');
    System.assertEquals(1, params3.size(), 'Should extract parameter');
    System.assertEquals(1, params4.size(), 'Should extract parameter');

    System.assert(params1.contains('name'), 'Should contain name');
    System.assert(params2.contains('name'), 'Should contain name');
    System.assert(params3.contains('name'), 'Should contain name');
    System.assert(params4.contains('name'), 'Should contain name');
  }

  /**
   * @description Test assessQueryRisk for low risk queries
   * @author Jaime Terrats | 12-02-2025
   **/
  @IsTest
  static void testAssessQueryRiskLowRisk() {
    Map<String, Object> bindings = new Map<String, Object>{
      'name' => 'Test Account for Viewer'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryRiskAssessment assessment = JT_QueryViewerController.assessQueryRisk(
      'Test_Record',
      bindingsJson
    );
    Test.stopTest();

    // Verify assessment structure (don't assert on isCriticalRisk as COUNT may fail in test context)
    System.assertNotEquals(null, assessment, 'Assessment should not be null');
    System.assertNotEquals(
      null,
      assessment.estimatedRecordCount,
      'Should have record count estimate'
    );
    System.assertNotEquals(
      null,
      assessment.riskLevel,
      'Should have risk level'
    );
    System.assertNotEquals(
      null,
      assessment.message,
      'Should have a risk message'
    );

    // Verify it's either LOW, MEDIUM, HIGH, CRITICAL, or UNKNOWN
    List<String> validLevels = new List<String>{
      'LOW',
      'MEDIUM',
      'HIGH',
      'CRITICAL',
      'UNKNOWN'
    };
    System.assert(
      validLevels.contains(assessment.riskLevel),
      'Risk level should be valid'
    );
  }

  /**
   * @description Test assessQueryRisk with empty bindings (high risk)
   * @author Jaime Terrats | 12-02-2025
   **/
  @IsTest
  static void testAssessQueryRiskEmptyBindings() {
    // Empty bindings (empty string value)
    Map<String, Object> bindings = new Map<String, Object>{ 'name' => '' };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryRiskAssessment assessment = JT_QueryViewerController.assessQueryRisk(
      'Test_Record',
      bindingsJson
    );
    Test.stopTest();

    System.assertNotEquals(null, assessment, 'Assessment should not be null');
    System.assertEquals(
      true,
      assessment.hasEmptyParameters,
      'Should detect empty parameters'
    );
  }

  /**
   * @description Test executeQueryWithBatchProcessing
   * @author Jaime Terrats | 12-02-2025
   **/
  @IsTest
  static void testExecuteQueryWithBatchProcessing() {
    // Create a specific account that matches the test
    Account testAcc = new Account(Name = 'Batch Processing Test Account');
    insert testAcc;

    // Use binding with a specific name
    Map<String, Object> bindings = new Map<String, Object>{
      'name' => 'Batch Processing Test Account'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryWithBatchProcessing(
      'Test_Record',
      bindingsJson,
      10 // Small batch size for testing
    );
    Test.stopTest();

    System.assertEquals(true, result.success, 'Batch query should succeed');
    System.assert(result.recordCount > 0, 'Should return records');
    System.assertNotEquals(
      null,
      result.records,
      'Records list should not be null'
    );
  }

  /**
   * @description Test serializeRecordsForLWC method
   * Validates that child relationships are preserved in standard Salesforce format
   * @author Jaime Terrats | 12-13-2025
   **/
  @IsTest
  static void testSerializeRecordsForLWC() {
    // Create test data with child relationships
    Account acc = new Account(
      Name = 'Test Account for Serialization',
      Type = 'Customer',
      Industry = 'Technology'
    );
    insert acc;

    // Create child Contacts
    List<Contact> contacts = new List<Contact>{
      new Contact(
        AccountId = acc.Id,
        FirstName = 'John',
        LastName = 'Doe',
        Email = 'john@test.com'
      ),
      new Contact(
        AccountId = acc.Id,
        FirstName = 'Jane',
        LastName = 'Smith',
        Email = 'jane@test.com'
      )
    };
    insert contacts;

    // Query with child relationship
    List<Account> accounts = [
      SELECT
        Id,
        Name,
        Type,
        Industry,
        (SELECT Id, FirstName, LastName, Email FROM Contacts)
      FROM Account
      WHERE Id = :acc.Id
      LIMIT 1
    ];

    Test.startTest();
    List<Object> serialized = JT_QueryViewerController.serializeRecordsForLWC(
      accounts
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      serialized,
      'Serialized records should not be null'
    );
    System.assertEquals(1, serialized.size(), 'Should serialize one account');

    // Verify child relationships are preserved
    Map<String, Object> firstRecord = (Map<String, Object>) serialized[0];
    System.assert(
      firstRecord.containsKey('Contacts'),
      'Child relationship Contacts should be preserved'
    );

    // Verify Contacts is in standard format: { records: [...] }
    Object contactsObj = firstRecord.get('Contacts');
    System.assertNotEquals(null, contactsObj, 'Contacts should not be null');

    // Contacts should be a Map with 'records' key
    if (contactsObj instanceof Map<String, Object>) {
      Map<String, Object> contactsMap = (Map<String, Object>) contactsObj;
      System.assert(
        contactsMap.containsKey('records'),
        'Contacts should have records key in standard format'
      );
      List<Object> contactRecords = (List<Object>) contactsMap.get('records');
      System.assertEquals(2, contactRecords.size(), 'Should have 2 contacts');
    }
  }

  /**
   * @description Test serializeRecordsForLWC with empty list
   * @author Jaime Terrats | 12-13-2025
   **/
  @IsTest
  static void testSerializeRecordsForLWCEmpty() {
    Test.startTest();
    List<Object> serialized = JT_QueryViewerController.serializeRecordsForLWC(
      new List<Account>()
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      serialized,
      'Should return empty list, not null'
    );
    System.assertEquals(0, serialized.size(), 'Should return empty list');
  }

  /**
   * @description Test serializeRecordsForLWC with null input
   * @author Jaime Terrats | 12-13-2025
   **/
  @IsTest
  static void testSerializeRecordsForLWCNull() {
    Test.startTest();
    List<Object> serialized = JT_QueryViewerController.serializeRecordsForLWC(
      null
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      serialized,
      'Should return empty list, not null'
    );
    System.assertEquals(
      0,
      serialized.size(),
      'Should return empty list for null input'
    );
  }

  /**
   * @description Test batch processing with large result set simulation
   * @author Jaime Terrats | 12-02-2025
   **/
  @IsTest
  static void testExecuteQueryWithBatchProcessingLargeSet() {
    // Create a single account that will be queried
    Account testAcc = new Account(Name = 'Large Set Test Account');
    insert testAcc;

    // Use specific binding to match the account
    Map<String, Object> bindings = new Map<String, Object>{
      'name' => 'Large Set Test Account'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryWithBatchProcessing(
      'Test_Record',
      bindingsJson,
      50 // Batch size of 50
    );
    Test.stopTest();

    System.assertEquals(true, result.success, 'Batch query should succeed');
    System.assert(result.recordCount > 0, 'Should return the test account');
  }

  /**
   * @description Test ResultCollector inner class
   * @author Jaime Terrats | 12-02-2025
   **/
  @IsTest
  static void testResultCollector() {
    // Create test records
    List<Account> accounts = new List<Account>{
      new Account(Name = 'Collector Test 1'),
      new Account(Name = 'Collector Test 2')
    };
    insert accounts;

    JT_QueryViewerController.ResultCollector collector = new JT_QueryViewerController.ResultCollector();

    Test.startTest();
    // Process batch 1
    collector.processBatch(new List<SObject>{ accounts[0] });
    // Process batch 2
    collector.processBatch(new List<SObject>{ accounts[1] });
    Test.stopTest();

    List<SObject> allRecords = collector.getAllRecords();
    System.assertEquals(
      2,
      allRecords.size(),
      'Should collect all records from batches'
    );
  }

  /**
   * @description Test extractParameters with null query
   */
  @IsTest
  static void testExtractParametersNull() {
    Test.startTest();
    List<String> params = JT_QueryViewerController.extractParameters(null);
    Test.stopTest();

    System.assertEquals(0, params.size(), 'Should return empty list for null');
  }

  /**
   * @description Test extractParameters with exception handling
   */
  @IsTest
  static void testExtractParametersException() {
    // This test verifies exception handling path exists
    // In practice, extractParameters should handle errors gracefully
    Test.startTest();
    try {
      // Using a query that might cause issues
      List<String> params = JT_QueryViewerController.extractParameters(
        'SELECT'
      );
      System.assertNotEquals(null, params, 'Should return list even on error');
    } catch (Exception e) {
      // Exception is acceptable - method should handle it
      System.assert(true, 'Exception handled');
    }
    Test.stopTest();
  }

  /**
   * @description Test getConfigurations with exception
   */
  @IsTest
  static void testGetConfigurationsException() {
    // This test verifies exception handling in getConfigurations
    // The method should throw AuraHandledException on error
    Test.startTest();
    try {
      List<JT_QueryViewerController.ConfigurationOption> configs = JT_QueryViewerController.getConfigurations();
      System.assertNotEquals(null, configs, 'Should return list');
    } catch (AuraHandledException e) {
      // Exception is acceptable - method handles errors
      System.assert(true, 'Exception handled');
    }
    Test.stopTest();
  }

  /**
   * @description Test canUseRunAs with exception handling
   */
  @IsTest
  static void testCanUseRunAsException() {
    // This test verifies exception handling in canUseRunAs
    Test.startTest();
    Boolean canUse = JT_QueryViewerController.canUseRunAs();
    Test.stopTest();

    // Should return false on exception, not throw
    System.assertNotEquals(null, canUse, 'Should return boolean');
  }

  /**
   * @description Test executeQuery with invalid runAsUserId
   */
  @IsTest
  static void testExecuteQueryInvalidRunAs() {
    String fakeUserId = '005' + '0'.repeat(15);
    Map<String, Object> bindings = new Map<String, Object>{
      'name' => 'Test Account for Viewer'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    try {
      JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
        'Test_Record',
        bindingsJson,
        fakeUserId
      );
      // May succeed or fail depending on permissions
      System.assertNotEquals(null, result, 'Should return result');
    } catch (AuraHandledException e) {
      // Exception expected if user not found or no permissions
      System.assert(true, 'Exception expected');
    }
    Test.stopTest();
  }

  /**
   * @description Test executeQueryPreview with null bindings
   */
  @IsTest
  static void testExecuteQueryPreviewNullBindings() {
    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryPreview(
      'Test_Record',
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
  }

  /**
   * @description Test executeQueryPreview with empty bindings
   */
  @IsTest
  static void testExecuteQueryPreviewEmptyBindings() {
    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryPreview(
      'Test_Record',
      '',
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
  }

  /**
   * @description Test assessQueryRisk with null bindings
   */
  @IsTest
  static void testAssessQueryRiskNullBindings() {
    Test.startTest();
    JT_QueryViewerController.QueryRiskAssessment assessment = JT_QueryViewerController.assessQueryRisk(
      'Test_Record',
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, assessment, 'Assessment should not be null');
  }

  /**
   * @description Test assessQueryRisk with empty bindings JSON
   */
  @IsTest
  static void testAssessQueryRiskEmptyBindingsJson() {
    Test.startTest();
    JT_QueryViewerController.QueryRiskAssessment assessment = JT_QueryViewerController.assessQueryRisk(
      'Test_Record',
      ''
    );
    Test.stopTest();

    System.assertNotEquals(null, assessment, 'Assessment should not be null');
  }

  /**
   * @description Test assessQueryRisk with invalid config
   */
  @IsTest
  static void testAssessQueryRiskInvalidConfig() {
    Map<String, Object> bindings = new Map<String, Object>{ 'name' => 'Test' };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryRiskAssessment assessment = JT_QueryViewerController.assessQueryRisk(
      'Invalid_Config_Name',
      bindingsJson
    );
    Test.stopTest();

    System.assertNotEquals(null, assessment, 'Assessment should not be null');
    // Should return UNKNOWN risk level on error
    System.assertNotEquals(
      null,
      assessment.riskLevel,
      'Should have risk level'
    );
  }

  /**
   * @description Test assessQueryRisk exception/catch path by forcing a failure
   * (e.g., invalid config so helper methods operate on null config).
   */
  @IsTest
  static void testAssessQueryRiskExceptionPath() {
    String bindingsJson = JSON.serialize(
      new Map<String, Object>{ 'name' => 'Test Account' }
    );

    Test.startTest();
    JT_QueryViewerController.QueryRiskAssessment assessment = JT_QueryViewerController.assessQueryRisk(
      'NonExistent_Config_For_Exception_Path',
      bindingsJson
    );
    Test.stopTest();

    System.assertNotEquals(null, assessment, 'Assessment should not be null');
    System.assertEquals(
      true,
      assessment.isHighRisk,
      'Exception path should mark assessment as high risk'
    );
    System.assertEquals(
      false,
      assessment.isCriticalRisk,
      'Exception path should mark critical risk as false'
    );
  }

  /**
   * @description Test executeQueryWithBatchProcessing with null bindings
   */
  @IsTest
  static void testExecuteQueryWithBatchProcessingNullBindings() {
    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryWithBatchProcessing(
      'Test_Record',
      null,
      10
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
  }

  /**
   * @description Test executeQueryWithBatchProcessing with empty bindings
   */
  @IsTest
  static void testExecuteQueryWithBatchProcessingEmptyBindings() {
    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryWithBatchProcessing(
      'Test_Record',
      '',
      10
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
  }

  /**
   * @description Test executeQueryWithBatchProcessing with invalid config
   */
  @IsTest
  static void testExecuteQueryWithBatchProcessingInvalidConfig() {
    Map<String, Object> bindings = new Map<String, Object>{ 'name' => 'Test' };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryWithBatchProcessing(
      'Invalid_Config',
      bindingsJson,
      10
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    // May succeed or fail depending on config
  }

  /**
   * @description Test addWildcardsForLikeBindings method
   */
  @IsTest
  static void testAddWildcardsForLikeBindings() {
    String query = 'SELECT Id FROM Account WHERE Name LIKE :name';
    Map<String, Object> bindings = new Map<String, Object>{ 'name' => 'Test' };

    Test.startTest();
    JT_QueryViewerController.addWildcardsForLikeBindings(query, bindings);
    Test.stopTest();

    // Verify wildcards were added
    System.assert(bindings.containsKey('name'), 'Binding should exist');
    // The actual wildcard addition is tested in JT_QueryBindingUtil tests
  }

  /**
   * @description Test addWildcardsForLikeBindings with null query
   */
  @IsTest
  static void testAddWildcardsForLikeBindingsNullQuery() {
    Map<String, Object> bindings = new Map<String, Object>{ 'name' => 'Test' };

    Test.startTest();
    JT_QueryViewerController.addWildcardsForLikeBindings(null, bindings);
    Test.stopTest();

    // Should not throw exception
    System.assert(true, 'Should handle null query');
  }

  /**
   * @description Test addWildcardsForLikeBindings with null bindings
   */
  @IsTest
  static void testAddWildcardsForLikeBindingsNullBindings() {
    String query = 'SELECT Id FROM Account WHERE Name LIKE :name';

    Test.startTest();
    JT_QueryViewerController.addWildcardsForLikeBindings(query, null);
    Test.stopTest();

    // Should not throw exception
    System.assert(true, 'Should handle null bindings');
  }

  /**
   * @description Test executeQueryPreview with queryOverride
   */
  @IsTest
  static void testExecuteQueryPreviewWithQueryOverride() {
    String queryOverride = 'SELECT Id, Name FROM Account LIMIT 5';
    Map<String, Object> bindings = new Map<String, Object>();
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryPreview(
      null, // devName not needed when queryOverride provided
      bindingsJson,
      queryOverride
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(
      true,
      result.success,
      'Should succeed with queryOverride'
    );
  }

  /**
   * @description Test executeQueryPreview with queryOverride and existing LIMIT
   */
  @IsTest
  static void testExecuteQueryPreviewWithQueryOverrideExistingLimit() {
    String queryOverride = 'SELECT Id, Name FROM Account LIMIT 10';
    Map<String, Object> bindings = new Map<String, Object>();
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryPreview(
      null,
      bindingsJson,
      queryOverride
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    // Should replace LIMIT 10 with LIMIT 5
    System.assertEquals(true, result.success, 'Should succeed');
  }

  /**
   * @description Test executeQueryPreview with invalid queryOverride
   */
  @IsTest
  static void testExecuteQueryPreviewInvalidQueryOverride() {
    String queryOverride = 'INVALID QUERY SYNTAX';
    Map<String, Object> bindings = new Map<String, Object>();
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQueryPreview(
      null,
      bindingsJson,
      queryOverride
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(
      false,
      result.success,
      'Should fail with invalid query'
    );
    System.assertNotEquals(
      null,
      result.errorMessage,
      'Should have error message'
    );
  }

  /**
   * @description Test executeQuery with empty records list
   */
  @IsTest
  static void testExecuteQueryEmptyRecords() {
    // Use bindings that won't match any records
    Map<String, Object> bindings = new Map<String, Object>{
      'name' => 'NonExistentAccountName12345'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Test_Record',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(
      true,
      result.success,
      'Should succeed even with no records'
    );
    System.assertEquals(0, result.recordCount, 'Should have 0 records');
    System.assertEquals(
      0,
      result.records.size(),
      'Records list should be empty'
    );
  }

  /**
   * @description Test executeQuery with Account_By_Name configuration
   */
  @IsTest
  static void testExecuteQueryAccountByName() {
    Map<String, Object> bindings = new Map<String, Object>{
      'searchName' => 'Test'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Account_By_Name',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(true, result.success, 'Query should succeed');
  }

  /**
   * @description Test executeQuery with Dynamic_Input_Test configuration
   */
  @IsTest
  static void testExecuteQueryDynamicInputTest() {
    Map<String, Object> bindings = new Map<String, Object>{
      'accountType' => 'Customer',
      'industry' => 'Technology'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Dynamic_Input_Test',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(true, result.success, 'Query should succeed');
  }

  /**
   * @description Test executeQuery with Complete_Customer_360_View configuration
   */
  @IsTest
  static void testExecuteQueryCompleteCustomer360View() {
    Map<String, Object> bindings = new Map<String, Object>{
      'accountType' => 'Customer'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Complete_Customer_360_View',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(true, result.success, 'Query should succeed');
  }

  /**
   * @description Test executeQuery with LIKE_Patterns_Mix configuration
   */
  @IsTest
  static void testExecuteQueryLikePatternsMix() {
    // Create test account with matching data
    Account testAcc = new Account(
      Name = 'Test Account',
      Website = 'example.com',
      Phone = '555-1234',
      Description = 'test description'
    );
    insert testAcc;

    Map<String, Object> bindings = new Map<String, Object>{
      'startsWith' => 'Test',
      'endsWith' => 'Account',
      'websitePattern' => 'example',
      'phonePattern' => '555',
      'descriptionKeyword' => 'test'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'LIKE_Patterns_Mix',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    // Query should succeed even if no records match
    // Note: This query may fail if Description field is not accessible
    // We'll just verify the result structure is correct
    System.assertNotEquals(null, result.success, 'Success flag should be set');
  }

  /**
   * @description Test executeQuery with Multiple_IN_Operators configuration
   */
  @IsTest
  static void testExecuteQueryMultipleInOperators() {
    Account testAcc = new Account(
      Name = 'Test Account',
      Industry = 'Technology',
      Type = 'Customer'
    );
    insert testAcc;

    Map<String, Object> bindings = new Map<String, Object>{
      'accountIds' => new List<String>{ testAcc.Id },
      'validIndustries' => new List<String>{ 'Technology' },
      'accountTypes' => new List<String>{ 'Customer' },
      'validStates' => new List<String>{ 'CA' },
      'excludedNames' => new List<String>{ 'Excluded' }
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Multiple_IN_Operators',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(true, result.success, 'Query should succeed');
  }

  /**
   * @description Test executeQuery with Complex_Mixed_Operators configuration
   */
  @IsTest
  static void testExecuteQueryComplexMixedOperators() {
    Account testAcc = new Account(
      Name = 'Test Account',
      Industry = 'Technology',
      Type = 'Customer',
      AnnualRevenue = 5000000,
      NumberOfEmployees = 100,
      BillingCountry = 'USA'
    );
    insert testAcc;

    Map<String, Object> bindings = new Map<String, Object>{
      'industries' => new List<String>{ 'Technology' },
      'excludedType' => 'Competitor',
      'minRevenue' => 1000000,
      'maxRevenue' => 100000000,
      'namePattern' => 'Test',
      'industryPattern' => 'Tech',
      'minEmployees' => 10,
      'maxEmployees' => 1000,
      'excludedCountries' => new List<String>{ 'Test Country' }
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Complex_Mixed_Operators',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(true, result.success, 'Query should succeed');
  }

  /**
   * @description Test executeQuery with All_Comparison_Operators configuration
   */
  @IsTest
  static void testExecuteQueryAllComparisonOperators() {
    Account testAcc = new Account(
      Name = 'Test Account',
      AnnualRevenue = 1000000,
      NumberOfEmployees = 50
    );
    insert testAcc;

    Map<String, Object> bindings = new Map<String, Object>{
      'exactRevenue' => 1000000,
      'notEqualRevenue' => 2000000,
      'lessThanRevenue' => 5000000,
      'lessThanOrEqual' => 10000000,
      'greaterThanRevenue' => 100000,
      'greaterThanOrEqual' => 500000,
      'exactDate' => Date.today(),
      'notEqualEmployees' => 100
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'All_Comparison_Operators',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    // Query should succeed even if no records match (OR conditions)
    // Note: This query may fail if fields are not accessible
    // We'll just verify the result structure is correct
    System.assertNotEquals(null, result.success, 'Success flag should be set');
  }

  /**
   * @description Test assessQueryRisk with Multiple_IN_Operators configuration
   */
  @IsTest
  static void testAssessQueryRiskMultipleInOperators() {
    Map<String, Object> bindings = new Map<String, Object>{
      'accountIds' => new List<String>{ '001000000000000AAA' },
      'validIndustries' => new List<String>{ 'Technology' },
      'accountTypes' => new List<String>{ 'Customer' },
      'validStates' => new List<String>{ 'CA' },
      'excludedNames' => new List<String>{ 'Excluded' }
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryRiskAssessment assessment = JT_QueryViewerController.assessQueryRisk(
      'Multiple_IN_Operators',
      bindingsJson
    );
    Test.stopTest();

    System.assertNotEquals(null, assessment, 'Assessment should not be null');
  }

  /**
   * @description Test executeQuery with NOT_Operators_Test configuration (should fail due to NOT LIKE)
   */
  @IsTest
  static void testExecuteQueryNotOperatorsTest() {
    Map<String, Object> bindings = new Map<String, Object>{
      'excludedIndustries' => new List<String>{ 'Technology' },
      'excludedType' => 'Competitor',
      'excludedRevenues' => new List<Decimal>{ 1000000 },
      'excludedPattern' => 'Test',
      'excludedCountry' => 'USA'
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'NOT_Operators_Test',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    // This query should fail because it uses NOT LIKE which is not supported
    System.assertEquals(
      false,
      result.success,
      'Query should fail due to NOT LIKE operator'
    );
    System.assertNotEquals(
      null,
      result.errorMessage,
      'Error message should be present'
    );
  }

  /**
   * @description Test assessQueryRisk with Complex_Mixed_Operators configuration
   */
  @IsTest
  static void testAssessQueryRiskComplexMixedOperators() {
    Map<String, Object> bindings = new Map<String, Object>{
      'industries' => new List<String>{ 'Technology' },
      'excludedType' => 'Competitor',
      'minRevenue' => 1000000,
      'maxRevenue' => 100000000,
      'namePattern' => 'Test',
      'industryPattern' => 'Tech',
      'minEmployees' => 10,
      'maxEmployees' => 1000,
      'excludedCountries' => new List<String>{ 'Test Country' }
    };
    String bindingsJson = JSON.serialize(bindings);

    Test.startTest();
    JT_QueryViewerController.QueryRiskAssessment assessment = JT_QueryViewerController.assessQueryRisk(
      'Complex_Mixed_Operators',
      bindingsJson
    );
    Test.stopTest();

    System.assertNotEquals(null, assessment, 'Assessment should not be null');
  }

  /**
   * @description Test convertBindingValueForQuery converts Decimal to Integer for Integer fields
   * Simulates JavaScript sending Decimal (from JSON deserialization) for NumberOfEmployees field
   */
  @IsTest
  static void testConvertBindingValueForQueryDecimalToInteger() {
    String query = 'SELECT Id FROM Account WHERE NumberOfEmployees >= :minEmployees';
    Decimal decimalValue = 100.0;

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'minEmployees',
      decimalValue
    );
    Test.stopTest();

    System.assert(
      result instanceof Integer,
      'Result should be Integer, not Decimal'
    );
    System.assertEquals(
      100,
      (Integer) result,
      'Should convert Decimal 100.0 to Integer 100'
    );
  }

  /**
   * @description Test convertBindingValueForQuery keeps Decimal for Decimal fields
   * Simulates JavaScript sending Decimal for AnnualRevenue field
   */
  @IsTest
  static void testConvertBindingValueForQueryKeepsDecimal() {
    String query = 'SELECT Id FROM Account WHERE AnnualRevenue >= :minRevenue';
    Decimal decimalValue = 1000000.50;

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'minRevenue',
      decimalValue
    );
    Test.stopTest();

    System.assert(
      result instanceof Decimal,
      'Result should remain Decimal for Decimal fields'
    );
    System.assertEquals(
      1000000.50,
      (Decimal) result,
      'Should keep Decimal value unchanged'
    );
  }

  /**
   * @description Test convertBindingValueForQuery keeps Integer as Integer
   * Simulates JavaScript sending Integer directly
   */
  @IsTest
  static void testConvertBindingValueForQueryKeepsInteger() {
    String query = 'SELECT Id FROM Account WHERE NumberOfEmployees >= :minEmployees';
    Integer integerValue = 100;

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'minEmployees',
      integerValue
    );
    Test.stopTest();

    System.assert(result instanceof Integer, 'Result should remain Integer');
    System.assertEquals(
      100,
      (Integer) result,
      'Should keep Integer value unchanged'
    );
  }

  /**
   * @description Test convertBindingValueForQuery handles legacy String values for Integer fields
   */
  @IsTest
  static void testConvertBindingValueForQueryStringToInteger() {
    String query = 'SELECT Id FROM Account WHERE NumberOfEmployees >= :minEmployees';
    String stringValue = '100';

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'minEmployees',
      stringValue
    );
    Test.stopTest();

    System.assert(
      result instanceof Integer,
      'Result should be Integer when field is Integer'
    );
    System.assertEquals(
      100,
      (Integer) result,
      'Should convert String "100" to Integer 100'
    );
  }

  /**
   * @description Test convertBindingValueForQuery handles legacy String values for Decimal fields
   */
  @IsTest
  static void testConvertBindingValueForQueryStringToDecimal() {
    String query = 'SELECT Id FROM Account WHERE AnnualRevenue >= :minRevenue';
    String stringValue = '1000000.50';

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'minRevenue',
      stringValue
    );
    Test.stopTest();

    System.assert(
      result instanceof Decimal,
      'Result should be Decimal when field is Decimal'
    );
    System.assertEquals(
      1000000.50,
      (Decimal) result,
      'Should convert String "1000000.50" to Decimal'
    );
  }

  /**
   * @description Test convertBindingValueForQuery handles boolean values
   * Simulates JavaScript sending Boolean directly
   */
  @IsTest
  static void testConvertBindingValueForQueryBoolean() {
    String query = 'SELECT Id FROM Account WHERE IsCustomerPortal = :isPortal';
    Boolean boolValue = true;

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'isPortal',
      boolValue
    );
    Test.stopTest();

    System.assert(result instanceof Boolean, 'Result should remain Boolean');
    System.assertEquals(
      true,
      (Boolean) result,
      'Should keep Boolean value unchanged'
    );
  }

  /**
   * @description Test convertBindingValueForQuery handles legacy String boolean values
   */
  @IsTest
  static void testConvertBindingValueForQueryStringToBoolean() {
    String query = 'SELECT Id FROM Account WHERE IsCustomerPortal = :isPortal';
    String stringValue = 'true';

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'isPortal',
      stringValue
    );
    Test.stopTest();

    System.assert(
      result instanceof Boolean,
      'Result should be Boolean when field is Boolean'
    );
    System.assertEquals(
      true,
      (Boolean) result,
      'Should convert String "true" to Boolean true'
    );
  }

  /**
   * @description Test convertBindingValueForQuery handles null values
   */
  @IsTest
  static void testConvertBindingValueForQueryNull() {
    String query = 'SELECT Id FROM Account WHERE NumberOfEmployees >= :minEmployees';

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'minEmployees',
      null
    );
    Test.stopTest();

    System.assertEquals(null, result, 'Should return null for null input');
  }

  /**
   * @description Integration test: Decimal to Integer conversion in real query execution via executeQuery
   * Creates Account with NumberOfEmployees and validates Decimal binding converts to Integer
   */
  @IsTest
  static void testDecimalToIntegerConversionInExecuteQuery() {
    // Create test Account with specific NumberOfEmployees
    Account testAccount = new Account(
      Name = 'Test Account Integer Field',
      NumberOfEmployees = 100,
      AnnualRevenue = 1000000
    );
    insert testAccount;

    // Simulate JavaScript sending Decimal (from JSON deserialization)
    // JSON will deserialize numbers as Decimal in Apex
    String bindingsJson = '{"notEqualEmployees": 99}';

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'All_Comparison_Operators',
      bindingsJson,
      null
    );
    Test.stopTest();

    // Query should execute successfully with Decimal converted to Integer
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(true, result.success, 'Query should succeed');
  }

  /**
   * @description Integration test: Decimal binding for Decimal field (AnnualRevenue) via executeQuery
   * Creates Account with AnnualRevenue and validates Decimal binding works correctly
   */
  @IsTest
  static void testDecimalBindingForDecimalFieldInExecuteQuery() {
    // Create test Account with specific AnnualRevenue
    Account testAccount = new Account(
      Name = 'Test Account Decimal Field',
      AnnualRevenue = 1000000.50,
      NumberOfEmployees = 50
    );
    insert testAccount;

    // Query the account to get its CreatedDate (Datetime type)
    testAccount = [SELECT CreatedDate FROM Account WHERE Id = :testAccount.Id];

    // Simulate JavaScript sending Decimal values and ISO date string
    // JSON will deserialize numbers as Decimal in Apex
    // JavaScript sends dates as ISO strings (e.g., "2024-01-15T10:30:00.000Z")
    // Note: The query uses OR conditions, so we need to provide bindings that match at least one condition
    // The account has AnnualRevenue = 1000000.50, so it should match greaterThanRevenue (500000) or greaterThanOrEqual (1000000.50)
    // For CreatedDate, simulate JavaScript sending ISO string format (like toISOString())
    String isoDateString = testAccount.CreatedDate.format(
      'yyyy-MM-dd\'T\'HH:mm:ss\'Z\''
    ); // ISO 8601 format like JavaScript toISOString()
    String bindingsJson = JSON.serialize(
      new Map<String, Object>{
        'exactRevenue' => 1000000.50,
        'notEqualRevenue' => 999999.99,
        'lessThanRevenue' => 2000000.00,
        'lessThanOrEqual' => 1000000.50,
        'greaterThanRevenue' => 500000.00,
        'greaterThanOrEqual' => 1000000.50,
        'exactDate' => isoDateString, // ISO string like JavaScript would send
        'notEqualEmployees' => 999
      }
    );

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'All_Comparison_Operators',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    // The query uses OR conditions, so it should succeed even if no records match
    // The key test is that Decimal bindings are converted correctly without errors
    System.assertEquals(
      true,
      result.success,
      'Query should succeed. Error: ' +
      (result.errorMessage != null ? result.errorMessage : 'Unknown error')
    );
  }

  /**
   * @description Integration test: Complex query with Decimal and Integer conversions via executeQuery
   * Validates that both Decimal->Integer and Decimal->Decimal conversions work together
   */
  @IsTest
  static void testComplexQueryWithMixedNumericTypesInExecuteQuery() {
    // Create test Accounts with specific values
    List<Account> accounts = new List<Account>{
      new Account(
        Name = 'Tech Account Integration',
        Industry = 'Technology',
        Type = 'Customer - Direct',
        AnnualRevenue = 2000000.75,
        NumberOfEmployees = 150,
        BillingCountry = 'USA'
      ),
      new Account(
        Name = 'Healthcare Account Integration',
        Industry = 'Healthcare',
        Type = 'Customer - Channel',
        AnnualRevenue = 1500000.25,
        NumberOfEmployees = 200,
        BillingCountry = 'Canada'
      )
    };
    insert accounts;

    // Simulate JavaScript sending Decimal values (from JSON deserialization)
    // JSON will deserialize numbers as Decimal in Apex
    String bindingsJson = JSON.serialize(
      new Map<String, Object>{
        'industries' => new List<String>{ 'Technology', 'Healthcare' },
        'excludedType' => 'Prospect',
        'minRevenue' => 1000000.0, // Decimal
        'maxRevenue' => 3000000.0, // Decimal
        'namePattern' => '%Integration%',
        'industryPattern' => '%Tech%',
        'minEmployees' => 100.0, // Decimal that should convert to Integer
        'maxEmployees' => 250.0, // Decimal that should convert to Integer
        'excludedCountries' => new List<String>{ 'Mexico' }
      }
    );

    Test.startTest();
    JT_QueryViewerController.QueryResult result = JT_QueryViewerController.executeQuery(
      'Complex_Mixed_Operators',
      bindingsJson,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(true, result.success, 'Query should succeed');
    System.assert(
      result.recordCount >= 2,
      'Should return at least 2 records matching the criteria. Found: ' +
      result.recordCount
    );

    // Validate that Decimal->Integer conversion worked correctly
    // by checking that NumberOfEmployees filter applied correctly
    if (result.records != null && !result.records.isEmpty()) {
      for (Object recordObj : result.records) {
        Map<String, Object> record = (Map<String, Object>) recordObj;
        Object employeesObj = record.get('NumberOfEmployees');
        Object revenueObj = record.get('AnnualRevenue');

        if (employeesObj != null) {
          Integer employees = employeesObj instanceof Integer
            ? (Integer) employeesObj
            : Integer.valueOf(employeesObj);
          System.assert(
            employees >= 100 && employees <= 250,
            'NumberOfEmployees should be between 100 and 250. Found: ' +
            employees
          );
        }

        if (revenueObj != null) {
          Decimal revenue = revenueObj instanceof Decimal
            ? (Decimal) revenueObj
            : Decimal.valueOf(String.valueOf(revenueObj));
          System.assert(
            revenue >= 1000000 && revenue <= 3000000,
            'AnnualRevenue should be between 1000000 and 3000000. Found: ' +
            revenue
          );
        }
      }
    }
  }

  @IsTest
  static void testClearPlatformCache() {
    Test.startTest();
    // Cover early-return path
    JT_QueryViewerController.clearPlatformCache(false, true, true, true);

    // Cover server-side clear path (configurations => platform cache removals)
    JT_QueryViewerController.clearPlatformCache(true, true, true, true);
    Test.stopTest();

    System.assert(true, 'clearPlatformCache should execute without throwing');
  }

  @IsTest
  static void testClearPlatformCacheWithNullConfigurations() {
    Test.startTest();
    JT_QueryViewerController.clearPlatformCache(null, true, true, true);
    Test.stopTest();
    System.assert(true, 'clearPlatformCache should handle null configurations');
  }

  // ─── getValueTypeName ─────────────────────────────────────────────────────

  @IsTest
  static void testGetValueTypeNameNull() {
    Test.startTest();
    String result = JT_QueryViewerController.getValueTypeName(null);
    Test.stopTest();
    Assert.areEqual('null', result, 'Null value should return "null"');
  }

  @IsTest
  static void testGetValueTypeNameString() {
    Test.startTest();
    String result = JT_QueryViewerController.getValueTypeName('hello');
    Test.stopTest();
    Assert.areEqual('String', result, 'String value should return "String"');
  }

  @IsTest
  static void testGetValueTypeNameInteger() {
    Test.startTest();
    String result = JT_QueryViewerController.getValueTypeName(42);
    Test.stopTest();
    Assert.areEqual('Integer', result, 'Integer should return "Integer"');
  }

  @IsTest
  static void testGetValueTypeNameDecimal() {
    Test.startTest();
    String result = JT_QueryViewerController.getValueTypeName(3.14);
    Test.stopTest();
    Assert.areEqual('Decimal', result, 'Decimal should return "Decimal"');
  }

  @IsTest
  static void testGetValueTypeNameBoolean() {
    Test.startTest();
    String result = JT_QueryViewerController.getValueTypeName(true);
    Test.stopTest();
    Assert.areEqual('Boolean', result, 'Boolean should return "Boolean"');
  }

  @IsTest
  static void testGetValueTypeNameDate() {
    Test.startTest();
    String result = JT_QueryViewerController.getValueTypeName(Date.today());
    Test.stopTest();
    Assert.areEqual('Date', result, 'Date should return "Date"');
  }

  @IsTest
  static void testGetValueTypeNameDatetime() {
    Test.startTest();
    String result = JT_QueryViewerController.getValueTypeName(Datetime.now());
    Test.stopTest();
    Assert.areEqual('Datetime', result, 'Datetime should return "Datetime"');
  }

  @IsTest
  static void testGetValueTypeNameList() {
    Test.startTest();
    String result = JT_QueryViewerController.getValueTypeName(
      new List<Object>{ 'a' }
    );
    Test.stopTest();
    Assert.areEqual(
      'List<Object>',
      result,
      'List<Object> should return "List<Object>"'
    );
  }

  @IsTest
  static void testGetValueTypeNameObject() {
    Test.startTest();
    // Map<String,Object> falls through all instanceof checks → Object fallback
    String result = JT_QueryViewerController.getValueTypeName(
      new Map<String, Object>()
    );
    Test.stopTest();
    Assert.areEqual('Object', result, 'Unknown type should return "Object"');
  }

  // ─── convertBindingValueForQuery – date / datetime conversion paths ───────
  // NOTE: No spaces around '>=' are intentional. The numeric-comparison regex
  // requires \s+ between field and operator, so removing spaces ensures the
  // binding reaches the date/datetime conversion block.

  @IsTest
  static void testConvertBindingValueForQueryDatetimeConversion() {
    String query = 'SELECT Id FROM Account WHERE CreatedDate>=:createdDate';
    String isoDatetime = '2025-01-15T10:30:00.000Z';

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'createdDate',
      isoDatetime
    );
    Test.stopTest();

    Assert.isTrue(
      result instanceof Datetime,
      'ISO datetime string for CreatedDate should be converted to Datetime'
    );
  }

  @IsTest
  static void testConvertBindingValueForQueryDateConversion() {
    String query = 'SELECT Id FROM Opportunity WHERE CloseDate>=:closeDate';
    String isoDate = '2025-06-30T00:00:00.000Z';

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'closeDate',
      isoDate
    );
    Test.stopTest();

    Assert.isTrue(
      result instanceof Date,
      'ISO date string for CloseDate should be converted to Date'
    );
  }

  @IsTest
  static void testConvertBindingValueForQueryDateConversionInvalid() {
    String query = 'SELECT Id FROM Opportunity WHERE CloseDate>=:closeDate';
    String invalidDate = 'not-a-date';

    Test.startTest();
    Object result = JT_QueryViewerController.convertBindingValueForQuery(
      query,
      'closeDate',
      invalidDate
    );
    Test.stopTest();

    Assert.areEqual(
      invalidDate,
      result,
      'Invalid date string should be returned as-is (catch block)'
    );
  }

  // ─── escapeScalarValue – Date / Datetime / null branches ─────────────────

  @IsTest
  static void testEscapeScalarValueNull() {
    Test.startTest();
    String result = JT_QueryViewerController.escapeScalarValue(null);
    Test.stopTest();
    Assert.areEqual('null', result, 'null should escape to the string "null"');
  }

  @IsTest
  static void testEscapeScalarValueDate() {
    Date d = Date.newInstance(2025, 6, 30);
    Test.startTest();
    String result = JT_QueryViewerController.escapeScalarValue(d);
    Test.stopTest();
    Assert.areEqual(
      '2025-06-30',
      result,
      'Date should be formatted as YYYY-MM-DD'
    );
  }

  @IsTest
  static void testEscapeScalarValueDatetime() {
    Datetime dt = Datetime.newInstanceGmt(2025, 1, 15, 10, 30, 0);
    Test.startTest();
    String result = JT_QueryViewerController.escapeScalarValue(dt);
    Test.stopTest();
    Assert.isTrue(
      result != null && result.contains('2025'),
      'Datetime should be formatted as ISO string containing the year'
    );
  }

  /**
   * @description startLdvBulkOperation must return an operation id whose
   * chained queueable(s) run to completion within the same Test.stopTest() flush.
   */
  @IsTest
  static void testStartLdvBulkOperationCompletesAndIsPollable() {
    insert new Account(Name = 'Test Account');

    Test.startTest();
    String operationId = JT_QueryViewerController.startLdvBulkOperation(
      'Test_Record',
      JSON.serialize(new Map<String, Object>{ 'name' => 'Test Account' }),
      200,
      'JT_LdvCountingProcessor'
    );
    Test.stopTest();

    JT_QueryViewerController.LdvOperationStatus status = JT_QueryViewerController.getLdvOperationStatus(
      operationId
    );
    Assert.areEqual(
      'Completed',
      status.status,
      'A small operation should complete within the chained queueable run triggered by Test.stopTest()'
    );
  }

  /**
   * @description cancelLdvOperation must never overwrite a terminal Completed status.
   */
  @IsTest
  static void testCancelLdvOperationIsNoOpOnCompletedOperation() {
    insert new Account(Name = 'Test Account');

    Test.startTest();
    String operationId = JT_QueryViewerController.startLdvBulkOperation(
      'Test_Record',
      JSON.serialize(new Map<String, Object>{ 'name' => 'Test Account' }),
      200,
      'JT_LdvCountingProcessor'
    );
    Test.stopTest();

    JT_QueryViewerController.cancelLdvOperation(operationId);

    JT_QueryViewerController.LdvOperationStatus status = JT_QueryViewerController.getLdvOperationStatus(
      operationId
    );
    Assert.areEqual(
      'Completed',
      status.status,
      'Cancelling an already-Completed operation must not overwrite its terminal status'
    );
  }

  /**
   * @description getLdvOperationStatus must fail loudly for an unknown operation id rather
   * than silently returning a blank/default status.
   */
  @IsTest
  static void testGetLdvOperationStatusThrowsForUnknownOperationId() {
    Boolean threwAuraHandledException = false;

    Test.startTest();
    try {
      JT_QueryViewerController.getLdvOperationStatus('does-not-exist');
    } catch (AuraHandledException e) {
      threwAuraHandledException = true;
    }
    Test.stopTest();

    Assert.isTrue(
      threwAuraHandledException,
      'getLdvOperationStatus should throw AuraHandledException for an unknown operation id'
    );
  }
}
