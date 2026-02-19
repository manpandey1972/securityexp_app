/**
 * Apple Push Notification Service (APNS) Client for VoIP Push
 *
 * This module handles sending VoIP push notifications to iOS devices
 * using the Apple Push Notification service HTTP/2 API.
 *
 * IMPORTANT: VoIP pushes MUST be sent via APNS, not FCM.
 * FCM does not support VoIP push notifications.
 */

import * as http2 from "http2";
import * as jwt from "jsonwebtoken";
import {defineSecret} from "firebase-functions/params";

// Define secrets for APNS authentication
// These should be set via: firebase functions:secrets:set APNS_KEY_ID
const apnsKeyId = defineSecret("APNS_KEY_ID");
const apnsTeamId = defineSecret("APNS_TEAM_ID");
const apnsPrivateKey = defineSecret("APNS_PRIVATE_KEY");
const apnsBundleId = defineSecret("APNS_BUNDLE_ID");

// APNS endpoints
const APNS_HOST_PRODUCTION = "api.push.apple.com";
const APNS_HOST_SANDBOX = "api.sandbox.push.apple.com";
const APNS_PORT = 443;

// Use sandbox for development builds (apps installed via Xcode)
// Set to false when your app is distributed via TestFlight or App Store
const USE_SANDBOX = true;

interface VoIPPayload {
  callId: string;
  callerId: string;
  callerName: string;
  callerAvatar?: string;
  hasVideo: boolean;
  roomName?: string;
  timestamp: number;
}

interface APNSResult {
  success: boolean;
  error?: string;
  statusCode?: number;
}

/**
 * Generate a JWT token for APNS authentication
 */
function generateAPNSToken(): string {
  const now = Math.floor(Date.now() / 1000);

  const header = {
    alg: "ES256",
    kid: apnsKeyId.value(),
  };

  const payload = {
    iss: apnsTeamId.value(),
    iat: now,
  };

  // The private key should be in PEM format
  const privateKey = apnsPrivateKey.value();

  return jwt.sign(payload, privateKey, {
    algorithm: "ES256",
    header: header,
  });
}

/**
 * Send a VoIP push notification via APNS HTTP/2
 */
export async function sendVoIPNotification(
  deviceToken: string,
  payload: VoIPPayload
): Promise<APNSResult> {
  const host = USE_SANDBOX ? APNS_HOST_SANDBOX : APNS_HOST_PRODUCTION;
  const bundleId = apnsBundleId.value();

  // VoIP push topic must end with .voip
  const topic = `${bundleId}.voip`;

  // Build the APNS payload
  // For VoIP pushes, the payload goes directly in the body
  const apnsPayload = {
    aps: {
      // VoIP pushes don't show UI - they wake the app
      "content-available": 1,
    },
    // Custom data for the call
    callId: payload.callId,
    callerId: payload.callerId,
    callerName: payload.callerName,
    callerAvatar: payload.callerAvatar || "",
    hasVideo: payload.hasVideo,
    roomName: payload.roomName || "",
    timestamp: payload.timestamp,
  };

  const body = JSON.stringify(apnsPayload);

  return new Promise((resolve) => {
    try {
      const client = http2.connect(`https://${host}:${APNS_PORT}`);

      client.on("error", (err) => {
        console.error("APNS connection error:", err);
        resolve({success: false, error: err.message});
      });

      const token = generateAPNSToken();

      const headers = {
        ":method": "POST",
        ":path": `/3/device/${deviceToken}`,
        ":scheme": "https",
        "authorization": `bearer ${token}`,
        "apns-topic": topic,
        "apns-push-type": "voip", // Critical: must be 'voip' for VoIP pushes
        "apns-priority": "10", // Immediate delivery
        "apns-expiration": String(Math.floor(Date.now() / 1000) + 60), // 60 second TTL
        "content-type": "application/json",
        "content-length": Buffer.byteLength(body),
      };

      const req = client.request(headers);

      let responseData = "";

      req.on("response", (headers) => {
        const status = headers[":status"] as number;

        req.on("data", (chunk) => {
          responseData += chunk;
        });

        req.on("end", () => {
          client.close();

          if (status === 200) {
            resolve({success: true, statusCode: status});
          } else {
            let errorMessage = `APNS error: ${status}`;
            try {
              const errorBody = JSON.parse(responseData);
              errorMessage = errorBody.reason || errorMessage;
            } catch {
              // Ignore JSON parse error
            }
            console.error(`APNS push failed: ${errorMessage}`);
            resolve({success: false, error: errorMessage, statusCode: status});
          }
        });
      });

      req.on("error", (err) => {
        client.close();
        console.error("APNS request error:", err);
        resolve({success: false, error: err.message});
      });

      req.write(body);
      req.end();
    } catch (error) {
      console.error("APNS send error:", error);
      resolve({success: false, error: String(error)});
    }
  });
}

