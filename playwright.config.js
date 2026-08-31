const { defineConfig, devices } = require("@playwright/test");

/**
 * @see https://playwright.dev/docs/test-configuration
 */
module.exports = defineConfig({
  testDir: "./tests/e2e",

  /* Seeds fixture data (e.g. Customer 360 Account + Contact/Opportunity/Case) so specs are
     self-contained and don't depend on ambient data in whichever org they run against. */
  globalSetup: require.resolve("./tests/e2e/global-setup.js"),

  /* Run tests in files in parallel */
  fullyParallel: false,

  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,

  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,

  /* Opt out of parallel tests on CI. */
  workers: process.env.CI ? 1 : 1,

  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: [["html", { outputFolder: "playwright-report" }], ["list"]],

  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: process.env.SF_INSTANCE_URL,

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: "on-first-retry",

    /* Screenshot on failure */
    screenshot: "only-on-failure",

    /* Video on failure */
    video: "retain-on-failure",

    /* Default timeout */
    actionTimeout: 15000,
    navigationTimeout: 30000,

    /* ✅ Performance & Cache Optimizations */
    launchOptions: {
      args: [
        "--disk-cache-size=100000000", // 100MB cache
        "--media-cache-size=100000000",
        "--aggressive-cache-discard",
        "--disable-blink-features=AutomationControlled"
      ]
    }
  },

  /* Configure projects for major browsers */
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    }
  ],

  /* Timeout for each test */
  timeout: 120000,

  /* Timeout for expect() assertions */
  expect: {
    timeout: 15000
  }
});
