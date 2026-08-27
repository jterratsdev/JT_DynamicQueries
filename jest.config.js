const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  testPathIgnorePatterns: [
    ...jestConfig.testPathIgnorePatterns,
    "<rootDir>/tests/e2e/"
  ]
};
