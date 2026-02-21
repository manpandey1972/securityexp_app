/**
 * E2EE barrel export.
 *
 * Re-exports all E2EE Cloud Function handlers for use in the
 * unified `api` callable in index.ts.
 */

export {
  handleRegisterDevice,
  handleDeregisterDevice,
  handleAttestPrekeyBundle,
  handleReplenishOPKs,
  handleRotateSignedPreKey,
  checkOPKSupply,
} from "./prekeyManagement";

export {
  handleStoreKeyBackup,
  handleRetrieveKeyBackup,
  handleDeleteKeyBackup,
  handleHasKeyBackup,
} from "./keyBackup";
