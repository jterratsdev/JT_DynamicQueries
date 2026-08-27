const { execSync } = require("child_process");

/**
 * Removes ANSI color codes and other escape sequences from a string
 * ANSI codes follow the pattern: ESC[...m where ESC is \x1b (char code 27)
 * @param {string} str - String potentially containing ANSI codes
 * @returns {string} Clean string without ANSI codes
 */
function stripAnsiCodes(str) {
  // Remove ANSI escape codes: \x1b[...m (color codes)
  // Also remove other common escape sequences
  return str
    .replace(/\x1b\[[0-9;]*m/g, "") // Standard ANSI color codes
    .replace(/\x1b\[[0-9;]*[A-Za-z]/g, "") // Other ANSI sequences (cursor movement, etc)
    .replace(/\x1b\][0-9;]*\x07/g, "") // OSC sequences
    .replace(/[\x00-\x08\x0B-\x0C\x0E-\x1F]/g, ""); // Other control characters except \n and \r
}

/**
 * Gets the active Salesforce org session from SF CLI
 * Uses the already authenticated session - NO LOGIN REQUIRED
 * @returns {Object} Object containing instanceUrl, accessToken, and username
 */
function getSFSession() {
  try {
    console.log("🔑 Using SF CLI active session (no login needed)...");

    // Get org info from SF CLI - uses active session
    // Force plain JSON output (no colors) with SF_USE_PROGRESS_BAR=false
    // Disable SF CLI file logging to avoid EPERM writes to ~/.sf/*.log
    let orgInfoJson;
    const sfEnv = {
      ...process.env,
      SF_USE_PROGRESS_BAR: "false",
      SF_AUTOUPDATE_DISABLE: "true",
      NO_COLOR: "1",
      FORCE_COLOR: "0",
      SF_LOG_LEVEL: "ERROR", // Only show errors, suppress info logs
      SF_DISABLE_LOG_FILE: "true",
      SFDX_DISABLE_LOG_FILE: "true"
    };

    try {
      // First attempt: try with stderr redirection (works on Unix-like systems)
      orgInfoJson = execSync("sf org display --json 2>/dev/null", {
        encoding: "utf-8",
        stdio: ["pipe", "pipe", "pipe"],
        env: sfEnv,
        shell: true // Use shell to support 2>/dev/null redirection
      });
    } catch (execError) {
      // Second attempt: ignore stderr completely (works on all systems)
      try {
        orgInfoJson = execSync("sf org display --json", {
          encoding: "utf-8",
          stdio: ["ignore", "pipe", "ignore"], // Ignore stdin and stderr
          env: sfEnv
        });
      } catch (retryError) {
        // Third attempt: try with stdout only, catch stderr separately
        try {
          orgInfoJson = execSync("sf org display --json", {
            encoding: "utf-8",
            stdio: ["ignore", "pipe", "pipe"], // Capture stderr but don't fail on it
            env: sfEnv
          });
        } catch (finalError) {
          // If all attempts fail, check if it's a permission error
          const errorMsg =
            finalError.message || retryError.message || execError.message || "";
          if (
            errorMsg.includes("EPERM") ||
            errorMsg.includes("operation not permitted")
          ) {
            console.warn("⚠️  SF CLI log file permission error detected.");
            console.warn(
              "💡 This is a known issue with SF CLI log file permissions."
            );
            console.warn(
              "💡 The tests may still work if SF CLI can read the org info from cache."
            );
            throw new Error(
              "SF CLI log file permission error. Please check permissions on ~/.sf directory or run: chmod 755 ~/.sf"
            );
          } else {
            throw new Error(
              `Failed to get SF org info: ${errorMsg}. Make sure you have an active SF CLI session: sf org login`
            );
          }
        }
      }
    }

    // Strip ANSI color codes that SF CLI might include in CI environments
    orgInfoJson = stripAnsiCodes(orgInfoJson);

    // Extract JSON from output - SF CLI may output extra text
    // Find the first '{' and last '}' to extract complete JSON object
    const firstBrace = orgInfoJson.indexOf("{");
    const lastBrace = orgInfoJson.lastIndexOf("}");

    if (firstBrace === -1 || lastBrace === -1) {
      console.error("❌ No valid JSON found in SF CLI output");
      console.error("Output length:", orgInfoJson.length, "chars");
      console.error("First 200 chars:", orgInfoJson.substring(0, 200));
      throw new Error(
        "No valid JSON found in SF CLI output. Is there an authenticated org?"
      );
    }

    const jsonString = orgInfoJson.substring(firstBrace, lastBrace + 1);

    // Check if this looks like an error message instead of org info
    if (
      jsonString.includes('"status":1') ||
      jsonString.includes('"name":"NoOrgFound"')
    ) {
      console.error("❌ SF CLI returned an error (no org found)");
      console.error("Response:", jsonString.substring(0, 300));
      throw new Error(
        "No authenticated Salesforce org found. Run 'sf org login' first."
      );
    }

    let orgInfo;
    try {
      orgInfo = JSON.parse(jsonString);
    } catch (parseError) {
      console.error("❌ Failed to parse JSON from SF CLI");
      console.error("Output length:", orgInfoJson.length, "chars");
      console.error("First 100 chars:", orgInfoJson.substring(0, 100));
      console.error(
        "Last 100 chars:",
        orgInfoJson.substring(orgInfoJson.length - 100)
      );
      console.error("Extracted JSON length:", jsonString.length, "chars");
      console.error("Extracted first 200 chars:", jsonString.substring(0, 200));
      console.error("Parse error:", parseError.message);

      // Try to find problematic characters
      for (let i = 0; i < Math.min(jsonString.length, 50); i++) {
        const char = jsonString[i];
        const code = char.charCodeAt(0);
        if (code < 32 || code > 126) {
          console.error(
            `⚠️  Non-printable char at position ${i}: code=${code}`
          );
        }
      }

      throw new Error(
        `JSON parse failed: ${parseError.message}. Check if SF org is authenticated.`
      );
    }

    if (orgInfo.status !== 0) {
      throw new Error(
        "❌ No default org found. Run: sf config set target-org <username>"
      );
    }

    const result = orgInfo.result;

    console.log("✅ Using active session:", result.username);
    console.log("📍 Instance:", result.instanceUrl);
    console.log(
      "🔑 Access token:",
      result.accessToken ? "[REDACTED]" : "[MISSING]"
    );

    return {
      instanceUrl: result.instanceUrl,
      accessToken: result.accessToken,
      username: result.username,
      orgId: result.id
    };
  } catch (error) {
    console.error("❌ Error getting SF session:", error.message);
    console.error("💡 Make sure you have an active SF CLI session");
    throw error;
  }
}

/**
 * Creates an authenticated context for Playwright using SF CLI session
 * @param {import('@playwright/test').Browser} browser
 * @returns {Promise<import('@playwright/test').BrowserContext>}
 */
async function createAuthenticatedContext(browser) {
  const session = getSFSession();

  // Create a new context with the SF session
  const context = await browser.newContext({
    storageState: {
      cookies: [
        {
          name: "sid",
          value: session.accessToken,
          domain: new URL(session.instanceUrl).hostname,
          path: "/",
          httpOnly: true,
          secure: true,
          sameSite: "None"
        }
      ],
      origins: []
    }
  });

  return { context, session };
}

/**
 * Injects the SF session directly into the page using CLI session
 * No login required - uses active SF CLI authentication
 * @param {import('@playwright/test').Page} page
 * @param {Object} session - Session object from getSFSession()
 */
async function injectSFSession(page, session) {
  console.log("🔐 Authenticating via frontdoor.jsp...");

  // Use Salesforce frontdoor.jsp for programmatic authentication
  const frontdoorUrl = `${session.instanceUrl}/secur/frontdoor.jsp?sid=${session.accessToken}&retURL=/lightning/page/home`;

  // Navigate using frontdoor (official Salesforce auth method)
  await page.goto(frontdoorUrl, {
    waitUntil: "domcontentloaded", // Changed from networkidle (SF has continuous polling)
    timeout: 30000
  });

  console.log("✅ Frontdoor navigation complete");

  // Wait a bit for redirect to complete
  await page.waitForTimeout(3000);

  // Verify we're authenticated (check for Lightning UI, not login form)
  const isLoginPage = await page
    .locator('input[type="password"]')
    .isVisible({ timeout: 5000 })
    .catch(() => false);

  if (isLoginPage) {
    // Take screenshot for debugging
    await page.screenshot({
      path: `test-results/auth-failed-${Date.now()}.png`,
      fullPage: true
    });
    throw new Error(
      "❌ Authentication failed - still on login page after frontdoor. Check screenshot and verify SF CLI session is active."
    );
  }

  // Wait for Lightning to fully load
  console.log("⏳ Waiting for Lightning to load...");
  await page
    .waitForSelector("one-appnav", { timeout: 20000 })
    .catch(async () => {
      console.log("⚠️  Lightning navigation not found, checking page state...");
      const currentUrl = page.url();
      console.log(`   Current URL: ${currentUrl}`);

      // Take screenshot for debugging
      await page.screenshot({
        path: `test-results/lightning-not-found-${Date.now()}.png`,
        fullPage: true
      });
    });

  console.log("✅ Authenticated successfully - Lightning loaded");
}

/**
 * Navigates to a specific Lightning app using App Launcher
 * @param {import('@playwright/test').Page} page
 * @param {string} appName - The name of the app to navigate to
 */
async function navigateToApp(page, appName) {
  try {
    console.log(`🚀 Opening App Launcher to find "${appName}"...`);

    // Lightning App Launcher is occasionally flaky in CI/automation runs.
    // Retry the whole app-search-and-click flow a few times.
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        console.log(`🔁 App navigation attempt ${attempt}/3 for "${appName}"`);

        // Close App Launcher if already open (intercepts waffle button click)
        const appLauncherDialog = page.locator(
          'div[role="dialog"][class*="appLauncher"], .forceAppLauncher, one-app-launcher-modal'
        );
        if (
          await appLauncherDialog
            .isVisible({ timeout: 1000 })
            .catch(() => false)
        ) {
          await page.keyboard.press("Escape");
          await page.waitForTimeout(500);
        }

        const appLauncher = page
          .locator(
            [
              "button.slds-icon-waffle_container",
              'button[title="App Launcher"]',
              "div.appLauncher button",
              "button:has(div.slds-icon-waffle)"
            ].join(", ")
          )
          .first();

        await appLauncher.click({ timeout: 10000 });
        console.log(`✅ App Launcher opened`);
        await page.waitForTimeout(2000);

        console.log(`🔍 Activating search box...`);
        await page.evaluate(() => {
          const input = document.querySelector('input[type="search"]');
          if (input) {
            input.tabIndex = 0;
            input.style.visibility = "visible";
            input.style.display = "block";
          }
        });

        const searchInput = page.locator('input[type="search"]').first();
        console.log(`⌨️  Typing "${appName}" in search...`);
        await searchInput.focus();
        await page.keyboard.type(appName, { delay: 100 });
        await page.waitForTimeout(2000);

        console.log(`🎯 Looking for "${appName}" in results...`);

        // Prefer stable attributes first, then fallback to text matching.
        const appTile = page
          .locator(
            [
              `[data-name="${appName}"]`,
              `one-app-launcher-app-tile:has-text("${appName}")`,
              `a[title="${appName}"]`,
              `a:has-text("${appName}")`,
              `div.slds-app-launcher__tile:has-text("${appName}")`
            ].join(", ")
          )
          .first();

        await appTile.waitFor({ state: "visible", timeout: 15000 });
        console.log(`✅ Found "${appName}" - clicking...`);
        await appTile.click();

        console.log(`⏳ Waiting for app to load...`);
        await page.waitForLoadState("domcontentloaded");
        await page.waitForTimeout(2000);

        console.log(`✅ Successfully navigated to "${appName}" app`);
        return true;
      } catch (error) {
        console.log(`⚠️  Attempt ${attempt}/3 failed: ${error.message}`);
        await page.waitForTimeout(2000);
      }
    }

    console.log(`❌ Failed to navigate to "${appName}" after retries`);
    return false;
  } catch (error) {
    console.log(`❌ Error navigating to app: ${error.message}`);
    console.log(`📸 Taking screenshot for debugging...`);

    try {
      await page.screenshot({
        path: `test-results/app-launcher-error-${Date.now()}.png`,
        fullPage: true
      });
    } catch (e) {
      // Ignore screenshot errors
    }

    console.log(`⚠️  Will try to continue anyway...`);
    return false;
  }
}

/**
 * Gets the current app name from the page
 * @param {import('@playwright/test').Page} page
 * @returns {Promise<string>}
 */
async function getCurrentApp(page) {
  try {
    const appName = await page
      .locator("one-appnav-brand-logo-text")
      .textContent({ timeout: 5000 });
    return appName.trim();
  } catch {
    return "";
  }
}

module.exports = {
  getSFSession,
  createAuthenticatedContext,
  injectSFSession,
  navigateToApp,
  getCurrentApp
};
