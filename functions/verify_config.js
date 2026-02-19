const admin = require('firebase-admin');

async function verify() {
  if (!admin.apps.length) {
    admin.initializeApp();
  }

  const remoteConfig = admin.remoteConfig();
  const template = await remoteConfig.getTemplate();

  console.log("\n=== Firebase Remote Config Parameters ===\n");
  Object.entries(template.parameters).forEach(([key, param]) => {
    const value = param.defaultValue?.value || param.defaultValue;
    console.log(`${key}:`, value);
  });

  console.log("\n✅ Config loaded successfully");
  process.exit(0);
}

verify().catch(err => {
  console.error("❌ Error:", err);
  process.exit(1);
});
