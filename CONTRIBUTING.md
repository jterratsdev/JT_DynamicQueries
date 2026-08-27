# Contributing to JT Dynamic Queries

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## 🌟 Ways to Contribute

- 🐛 Report bugs
- 💡 Suggest new features
- 📝 Improve documentation
- 🔧 Submit code fixes or enhancements
- 🌍 Add translations for new languages
- ✅ Write tests

---

## 🚀 Getting Started

### Prerequisites

- Salesforce Developer Org or Scratch Org
- Salesforce CLI (`sf` command)
- Node.js 24+ and npm
- Git

### Setup Development Environment

1. **Clone the repository:**

   ```bash
   git clone https://github.com/jterrats/JT_DynamicQueries.git
   cd JT_DynamicQueries
   ```

2. **Install dependencies:**

   ```bash
   npm install
   ```

3. **Create or authenticate to a Salesforce org:**

   ```bash
   # Option A: Create scratch org
   sf org create scratch --definition-file config/project-scratch-def.json --alias jt-dev --set-default

   # Option B: Authenticate to existing org
   sf org login web --alias jt-dev --set-default
   ```

4. **Deploy the project:**

   ```bash
   sf project deploy start
   ```

5. **Assign permission set:**

   ```bash
   sf org assign permset --name JT_Dynamic_Queries
   ```

6. **Run tests to verify setup:**

   ```bash
   # Apex tests
   sf apex run test --test-level RunLocalTests --result-format human

   # E2E tests
   npm run test:e2e
   ```

### Troubleshooting

**Pre-commit hook fails with `EPERM` on `~/.sf/*.log`:** the Husky pre-commit hook runs
`sf code-analyzer run`, which writes a log file under `~/.sf`. In some environments (restrictive
file permissions, certain CI runners) this write fails with `EPERM`. The `lint` and `lint:staged`
npm scripts set `SF_DISABLE_LOG_FILE=true` (and `SFDX_DISABLE_LOG_FILE=true`) to disable SF CLI
file logging entirely, avoiding the error regardless of `~/.sf` permissions.

---

## 📋 Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

**Branch naming conventions:**

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions/updates

### 2. Make Your Changes

**Code Guidelines:**

#### Apex Code

- Follow Salesforce Apex Best Practices
- Use ApexDoc comments for public methods
- Handle exceptions gracefully (try-catch blocks)
- Respect USER_MODE security
- Add test methods for new functionality

```apex
/**
 * @description Retrieves records using a dynamic query configuration
 * @param configName The developer name of the configuration
 * @return List of SObjects matching the query
 * @throws AuraHandledException if configuration not found or invalid
 */
@AuraEnabled(cacheable=true)
public static List<SObject> getRecords(String configName) {
    // Implementation
}
```

#### Lightning Web Components

- Follow LWC Best Practices
- Use JSDoc comments for methods
- Keep components small and focused (< 300 lines)
- Use functional programming patterns where applicable
- Ensure accessibility (ARIA attributes)

```javascript
/**
 * @description Filters options based on search term
 * @param {Array} options - Array of {value, label} objects
 * @param {String} searchTerm - Term to filter by
 * @returns {Array} Filtered options
 * @pure This is a pure function with no side effects
 */
const filterOptions = (options, searchTerm) => {
  // Implementation
};
```

### 3. Write Tests

**Required:**

- ✅ Apex test methods for new Apex code (aim for 85%+ coverage)
- ✅ E2E tests for new UI features
- ✅ Update existing tests if behavior changed

**Apex Test Example:**

```apex
@IsTest
private class YourClass_Test {
  @IsTest
  static void testYourMethod() {
    Test.startTest();
    // Your test logic
    Test.stopTest();

    System.assertEquals(expected, actual, 'Description');
  }
}
```

**E2E Test Example:**

```javascript
test("should test your feature", async ({ page }) => {
  // Navigate to component
  await page.waitForSelector("c-jt-query-viewer");

  // Interact with UI
  const button = page.locator("lightning-button").first();
  await button.click();

  // Assert outcome
  await expect(page.locator(".result")).toBeVisible();
});
```

### 4. Run Tests Locally

```bash
# Apex tests
sf apex run test --test-level RunLocalTests --result-format human --wait 15

# E2E tests (headless)
npx playwright test

# E2E tests (headed - for debugging)
npx playwright test --headed
```

### 5. Code Quality Checks

```bash
# PMD (Apex)
sf scanner run --target "force-app/main/default/classes" --engine pmd

# ESLint (LWC)
npm run lint

# Prettier (formatting)
npm run prettier
```

### 6. Commit Your Changes

**Commit Message Format:**

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Test additions/updates
- `chore`: Build/config changes

**Example:**

```
feat(lwc): add CSV export to query results viewer

- Implemented transformToCSV function using functional pattern
- Added export button to jtQueryResults component
- Included download trigger with proper filename
- Added translations for export button (8 languages)

Closes #42
```

### 7. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Create PR on GitHub with:

- Clear title describing the change
- Description of what was changed and why
- Screenshots/videos for UI changes
- Link to related issue(s)
- Test results (if applicable)

---

## 🧪 Testing Guidelines

### E2E Test Best Practices

1. **Use Semantic Selectors:**

   ```javascript
   // ❌ Bad - fragile
   await page.locator("div.class-123").click();

   // ✅ Good - semantic
   await page.locator("c-jt-searchable-combobox").locator("input").click();
   ```

2. **Wait for Elements:**

   ```javascript
   // Always wait for visibility before interacting
   await expect(element).toBeVisible({ timeout: 5000 });
   await element.click();
   ```

3. **Handle Async Operations:**

   ```javascript
   // Wait for spinners to disappear
   await page.waitForSelector("lightning-spinner", {
     state: "hidden",
     timeout: 10000
   });
   ```

4. **Provide Clear Console Logs:**
   ```javascript
   console.log("✅ Configuration selected successfully");
   console.log(`📊 Found ${count} results`);
   ```

### Apex Test Best Practices

1. **Use Test.startTest() / Test.stopTest():**

   ```apex
   Test.startTest();
   // Code that should run with fresh governor limits
   Test.stopTest();
   ```

2. **Create Minimal Test Data:**

   ```apex
   // Only create data needed for the test
   Account testAccount = new Account(Name = 'Test');
   insert testAccount;
   ```

3. **Test Negative Scenarios:**
   ```apex
   try {
       YourClass.methodThatShouldFail(null);
       System.assert(false, 'Should have thrown exception');
   } catch (Exception e) {
       System.assert(true, 'Exception correctly thrown');
   }
   ```

---

## 🌍 Adding Translations

### 1. Update JavaScript Labels

**File:** `force-app/main/default/lwc/*/labels.js`

```javascript
const LABELS = {
  en: {
    executeQuery: "Execute Query"
    // ... other labels
  },
  es: {
    executeQuery: "Ejecutar Consulta"
    // ... other labels
  },
  // Add your language here
  ko: {
    executeQuery: "쿼리 실행"
    // ... other labels
  }
};
```

### 2. Add Object Translations

**Path:** `force-app/main/default/objectTranslations/`

Create folder: `JT_DynamicQueryConfiguration__mdt-ko/`

**File:** `JT_DynamicQueryConfiguration__mdt-ko.objectTranslation-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CustomObjectTranslation xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>쿼리 구성</label>
    <fields>
        <name>JT_BaseQuery__c</name>
        <label>기본 쿼리</label>
    </fields>
    <!-- More fields -->
</CustomObjectTranslation>
```

### 3. Update Tests

Add test for new language in `queryViewer.spec.js`:

```javascript
test("should display Korean labels", async ({ page }) => {
  // Change browser locale to ko
  // Verify labels appear in Korean
});
```

---

## 📝 Documentation Guidelines

### Code Comments

**Apex:**

```apex
/**
 * @description Brief description
 * @param paramName Description of parameter
 * @return Description of return value
 * @throws ExceptionType When it's thrown
 */
```

**JavaScript:**

```javascript
/**
 * @description Brief description
 * @param {Type} paramName - Description
 * @returns {Type} Description
 * @fires eventname - When event is fired
 * @example
 * const result = myFunction(input);
 */
```

### Markdown Documentation

- Use clear headings (##, ###)
- Include code examples
- Add screenshots for UI features
- Provide both English and Spanish versions for major docs

---

## 🔍 Code Review Process

### What We Look For

1. ✅ **Functionality:** Does it work as intended?
2. ✅ **Tests:** Are there tests? Do they pass?
3. ✅ **Code Quality:** Follows best practices?
4. ✅ **Documentation:** Is it documented?
5. ✅ **Accessibility:** WCAG 2.1 AA compliant?
6. ✅ **Security:** FLS/CRUD checks, no SOQL injection?
7. ✅ **Performance:** Efficient queries, minimal API calls?
8. ✅ **i18n:** Translatable text in labels?

### Review Checklist

- [ ] Code follows project conventions
- [ ] All tests pass (Apex + E2E)
- [ ] No PMD violations
- [ ] No ESLint errors
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if user-facing change)
- [ ] No breaking changes (or clearly documented)
- [ ] Accessible (ARIA, keyboard nav)
- [ ] Responsive (mobile tested)
- [ ] Translated (if UI text)

---

## 🐛 Reporting Bugs

### Before Submitting

1. Check existing issues
2. Verify it's not a known limitation
3. Test in a clean org (if possible)

### Bug Report Template

```markdown
**Describe the bug**
Clear description of what's wrong

**To Reproduce**

1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior**
What should happen

**Screenshots**
If applicable

**Environment:**

- Org Type: (Sandbox/Production/Developer)
- Salesforce Edition: (Enterprise/Unlimited/etc.)
- Browser: (Chrome/Firefox/Safari)
- User Profile: (System Administrator/Custom)

**Additional context**
Any other relevant information
```

---

## 💡 Feature Requests

### Feature Request Template

```markdown
**Is your feature request related to a problem?**
Clear description of the problem

**Describe the solution you'd like**
What you want to happen

**Describe alternatives you've considered**
Other approaches you've thought of

**Additional context**
Screenshots, examples, use cases
```

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## 🙏 Thank You!

Your contributions make this project better for everyone. We appreciate your time and effort!

**Questions?** Open an issue or reach out to the maintainers.
