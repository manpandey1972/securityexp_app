/**
 * E2EE barrel export — v3 (KMS-protected per-room symmetric keys).
 *
 * Re-exports room key management handlers for use in the
 * unified `api` callable in index.ts.
 */

export {
  handleSealRoomKey,
  handleGetRoomKey,
} from "./roomKeyManagement";
