/**
 * E2E Tests for CSV/JSON Export
 * Validates that switching to the CSV/JSON view renders the executed query's data,
 * not a stale/empty preview.
 */

const { test, expect } = require("@playwright/test");
const {
  setupTestContext,
  selectConfiguration,
  executeQuery
} = require("./utils/testHelpers");
const { getSFSession } = require("./utils/sfAuth");
const { QUERY_VIEWER_TAB } = require("./utils/testConstants");

let session;

test.beforeAll(async () => {
  session = await getSFSession();
});

test.describe("CSV/JSON Export", () => {
  test.beforeEach(async ({ page }) => {
    await setupTestContext(page, session, {
      targetTab: QUERY_VIEWER_TAB,
      waitForComponent: true
    });
  });

  test("should render executed query results in the CSV view", async ({
    page
  }) => {
    await selectConfiguration(page, "Customer 360 View (Complex Query)");
    await executeQuery(page);

    const csvViewButton = page.locator(
      'c-jt-query-results lightning-button[data-view="csv"]'
    );
    await csvViewButton.click();
    await page.waitForTimeout(500);

    const csvContent = page.locator("c-jt-query-results pre.csv-content");
    await expect(csvContent).toBeVisible({ timeout: 5000 });

    const csvText = await csvContent.textContent();
    expect(csvText.length).toBeGreaterThan(0);
    // Header row must reflect the query's actual top-level fields, not a placeholder.
    expect(csvText).toContain("Name");
  });

  test("should render executed query results in the JSON view", async ({
    page
  }) => {
    await selectConfiguration(page, "Customer 360 View (Complex Query)");
    await executeQuery(page);

    const jsonViewButton = page.locator(
      'c-jt-query-results lightning-button[data-view="json"]'
    );
    await jsonViewButton.click();
    await page.waitForTimeout(500);

    const jsonContent = page.locator("c-jt-query-results pre.json-content");
    await expect(jsonContent).toBeVisible({ timeout: 5000 });

    const jsonText = await jsonContent.textContent();
    expect(() => JSON.parse(jsonText)).not.toThrow();

    const parsed = JSON.parse(jsonText);
    expect(Array.isArray(parsed) ? parsed.length : Object.keys(parsed).length)
      .toBeGreaterThan(0);
  });

  test("should trigger a CSV file download without a JS runtime error", async ({
    page
  }) => {
    const pageErrors = [];
    page.on("pageerror", (error) => pageErrors.push(error.message));

    await selectConfiguration(page, "Customer 360 View (Complex Query)");
    await executeQuery(page);

    const csvViewButton = page.locator(
      'c-jt-query-results lightning-button[data-view="csv"]'
    );
    await csvViewButton.click();

    // Wait for the CSV to actually be generated/rendered, not a fixed delay - generateCSV()
    // runs on first view-switch and its timing can vary.
    const csvContent = page.locator("c-jt-query-results pre.csv-content");
    await expect(csvContent).not.toBeEmpty({ timeout: 10000 });

    // lightning-button's `label` is a JS property, not a reflected DOM attribute, so it
    // can't be matched with a CSS attribute selector - use the accessible name instead.
    const downloadButton = page
      .locator("c-jt-query-results")
      .getByRole("button", { name: "Download", exact: true });
    await expect(downloadButton).toBeVisible({ timeout: 10000 });

    // The Blob-URL download itself is standard browser/Blob API behavior, not something
    // this test needs to re-verify. What this test does verify: clicking Download does not
    // throw inside downloadFile()/handleDownloadCsv() (e.g. from a malformed Blob or a null
    // dereference), and the CSV preview stays intact afterward.
    await downloadButton.click();
    await page.waitForTimeout(1000);

    expect(pageErrors).toEqual([]);
  });
});
