import {AccessToken} from "livekit-server-sdk";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";

interface TokenGenerationParams {
  userId: string;
  roomName: string;
  userName?: string;
}

interface TokenGenerationResult {
  token: string;
  userId: string;
  roomName: string;
  url: string;
}

/**
 * Fetch LiveKit configuration from Firebase Remote Config
 */
async function getLiveKitConfig(): Promise<{
  apiKey: string;
  apiSecret: string;
  url: string;
}> {
  try {
    const remoteConfig = admin.remoteConfig();
    const template = await remoteConfig.getTemplate();

    // Extract credentials - Remote Config wraps values in {value: "..."} format
    const keyParam = (template.parameters.livekit_api_key?.defaultValue as any);
    const secretParam = (template.parameters.livekit_api_secret?.defaultValue as any);
    const urlParam = (template.parameters.livekit_url?.defaultValue as any);

    const apiKey = keyParam?.value || keyParam;
    const apiSecret = secretParam?.value || secretParam;
    const url = urlParam?.value || urlParam;

    if (!apiKey || !apiSecret || !url) {
      throw new Error(
        "LiveKit configuration missing in Remote Config. Please set: livekit_api_key, livekit_api_secret, livekit_url"
      );
    }

    return {apiKey, apiSecret, url};
  } catch (error) {
    logger.error("Failed to fetch LiveKit config from Remote Config", {
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

/**
 * Generate a LiveKit access token for a user to join a room
 * @param params - Token generation parameters including userId, roomName, and optional userName
 * @return Token generation result with the access token
 */
export async function generateLiveKitToken(params: TokenGenerationParams): Promise<TokenGenerationResult> {
  const {userId, roomName, userName = userId} = params;

  const {apiKey, apiSecret, url: liveKitUrl} = await getLiveKitConfig();

  try {
    const token = new AccessToken(apiKey, apiSecret);

    // Set the token claims
    token.addGrant({
      room: roomName,
      roomJoin: true,
      canPublish: true,
      canPublishData: true,
      canSubscribe: true,
    });

    // Set identity and name
    token.identity = userId;
    token.name = userName;

    logger.info("LiveKit token generated successfully", {
      userId,
      roomName,
      userName,
    });

    return {
      token: await token.toJwt(),
      userId,
      roomName,
      url: liveKitUrl,
    };
  } catch (error) {
    logger.error("Failed to generate LiveKit token", {
      userId,
      roomName,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}

/**
 * Generate a LiveKit token with custom permissions
 * @param userId - The user ID
 * @param roomName - The room name
 * @param options - Custom token options
 * @return Token generation result with the access token
 */
export async function generateLiveKitTokenWithOptions(
  userId: string,
  roomName: string,
  options?: {
    canPublish?: boolean;
    canPublishData?: boolean;
    canSubscribe?: boolean;
    ttl?: number; // Token time-to-live in seconds
    userName?: string;
  }
): Promise<TokenGenerationResult> {
  const {
    canPublish = true,
    canPublishData = true,
    canSubscribe = true,
    ttl = 3600, // Default 1 hour
    userName = userId,
  } = options || {};

  // Get LiveKit configuration from Remote Config
  try {
    const {apiKey, apiSecret, url: liveKitUrl} = await getLiveKitConfig();

    const token = new AccessToken(apiKey, apiSecret);

    token.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish,
      canPublishData,
      canSubscribe,
    });

    token.identity = userId;
    token.name = userName;

    if (ttl) {
      token.ttl = ttl;
    }

    logger.info("LiveKit token with custom options generated", {
      userId,
      roomName,
      canPublish,
      canPublishData,
      canSubscribe,
      ttl,
    });

    return {
      token: await token.toJwt(),
      userId,
      roomName,
      url: liveKitUrl,
    };
  } catch (error) {
    logger.error("Failed to generate LiveKit token with options", {
      userId,
      roomName,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
}
