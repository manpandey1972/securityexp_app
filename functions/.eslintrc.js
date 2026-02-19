module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:import/errors",
    "plugin:import/warnings",
    "plugin:import/typescript",
    "google",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json", "tsconfig.dev.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
  ],
  plugins: [
    "@typescript-eslint",
    "import",
  ],
  rules: {
    "quotes": ["error", "double"],
    "import/no-unresolved": 0,
    "indent": ["error", 2],
    "max-len": ["warn", {code: 100}], // Relaxed line length
    "valid-jsdoc": "off", // JSDoc comments are nice but not critical
    "require-jsdoc": "off", // Allow functions without JSDoc
    "@typescript-eslint/no-explicit-any": "warn", // Warning for any types
    "camelcase": ["warn", {properties: "never"}], // Allow snake_case in properties
  },
};
