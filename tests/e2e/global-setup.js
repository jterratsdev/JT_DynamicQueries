const { execSync } = require("child_process");

/**
 * Idempotently seeds the minimum fixture data several E2E specs assume already exists
 * (e.g. bugfixes.spec.js's child-relationships check needs an Account with Type = 'Customer'
 * and at least one related Contact/Opportunity/Case). Uses anonymous Apex with
 * check-then-insert logic so it's safe to run against a fresh scratch org or a long-lived
 * dev org without creating duplicates on repeated runs.
 */
const SEED_APEX = `
Account acct;
List<Account> existingAccounts = [SELECT Id FROM Account WHERE Name = 'E2E Customer 360 Account' LIMIT 1];
if (existingAccounts.isEmpty()) {
  acct = new Account(
    Name = 'E2E Customer 360 Account',
    Type = 'Customer',
    Industry = 'Technology',
    AnnualRevenue = 5000000,
    BillingCity = 'San Francisco',
    BillingState = 'CA',
    BillingCountry = 'USA'
  );
  insert acct;
} else {
  acct = existingAccounts[0];
}

if ([SELECT COUNT() FROM Contact WHERE AccountId = :acct.Id] == 0) {
  insert new Contact(
    FirstName = 'E2E',
    LastName = 'TestContact',
    AccountId = acct.Id,
    Email = 'e2e.contact@example.com',
    Title = 'QA Lead',
    Department = 'Engineering'
  );
}

if ([SELECT COUNT() FROM Opportunity WHERE AccountId = :acct.Id AND IsClosed = false] == 0) {
  insert new Opportunity(
    Name = 'E2E Test Opportunity',
    AccountId = acct.Id,
    StageName = 'Prospecting',
    CloseDate = Date.today().addMonths(1),
    Amount = 10000,
    Type = 'New Business'
  );
}

if ([SELECT COUNT() FROM Case WHERE AccountId = :acct.Id AND IsClosed = false] == 0) {
  insert new Case(
    AccountId = acct.Id,
    Subject = 'E2E Test Case',
    Status = 'New',
    Priority = 'Medium',
    Origin = 'Web'
  );
}

System.debug('E2E_SEED_COMPLETE');
`;

module.exports = async function globalSetup() {
  console.log("🌱 Seeding E2E fixture data (Customer 360 Account + children)...");

  const sfEnv = {
    ...process.env,
    SF_USE_PROGRESS_BAR: "false",
    SF_AUTOUPDATE_DISABLE: "true",
    NO_COLOR: "1",
    FORCE_COLOR: "0",
    SF_LOG_LEVEL: "ERROR",
    SF_DISABLE_LOG_FILE: "true",
    SFDX_DISABLE_LOG_FILE: "true"
  };

  try {
    require("fs").writeFileSync("/tmp/e2e-seed.apex", SEED_APEX);
    const output = execSync("sf apex run --file /tmp/e2e-seed.apex --json", {
      encoding: "utf-8",
      env: sfEnv
    });
    const result = JSON.parse(output);
    if (result.result?.success === false || result.status === 1) {
      console.warn(
        "⚠️  E2E seed script reported failure - some specs may fail due to missing fixtures:",
        JSON.stringify(result.result || result)
      );
      return;
    }
    console.log("✅ E2E fixture data ready");
  } catch (error) {
    console.warn(
      "⚠️  Could not seed E2E fixture data - some specs may fail due to missing fixtures:",
      error.message
    );
  }
};
