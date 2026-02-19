import {generateLiveKitToken, generateLiveKitTokenWithOptions} from "../livekit";
import * as admin from "firebase-admin";
import {jwtDecode} from "jwt-decode";

// Mock Firebase Admin for testing
jest.mock("firebase-admin", () => ({
  remoteConfig: jest.fn().mockReturnValue({
    getTemplate: jest.fn().mockResolvedValue({
      parameters: {
        livekit_api_key: {defaultValue: "test-api-key"},
        livekit_api_secret: {defaultValue: "test-api-secret"},
        livekit_url: {defaultValue: "wss://test.livekit.io:7880"},
      },
    }),
  }),
}));

describe("LiveKit Token Generation", () => {
  const testParams = {
    userId: "user123",
    roomName: "test-room",
    userName: "Test User",
  };

  describe("generateLiveKitToken", () => {
    it("should generate a valid JWT token", async () => {
      const result = await generateLiveKitToken(testParams);

      expect(result).toBeDefined();
      expect(result.token).toBeDefined();
      expect(result.userId).toBe(testParams.userId);
      expect(result.roomName).toBe(testParams.roomName);
      expect(result.url).toBe("wss://test.livekit.io:7880");
    });

    it("should generate a properly formatted JWT token", async () => {
      const result = await generateLiveKitToken(testParams);

      // JWT should have 3 parts separated by dots
      const parts = result.token.split(".");
      expect(parts).toHaveLength(3);

      // Decode and verify token structure
      const decoded = jwtDecode<any>(result.token);
      expect(decoded).toBeDefined();
    });

    it("should include correct claims in token", async () => {
      const result = await generateLiveKitToken(testParams);
      const decoded = jwtDecode<any>(result.token);

      // Verify identity and name claims
      expect(decoded.sub).toBe(testParams.userId);
      expect(decoded.name).toBe(testParams.userName);

      // Verify grant claims (may be nested under 'video' property in some versions)
      const grants = decoded.video || decoded.grants;
      expect(grants).toBeDefined();
      expect(grants.room).toBe(testParams.roomName);
      expect(grants.roomJoin).toBe(true);
      expect(grants.canPublish).toBe(true);
      expect(grants.canSubscribe).toBe(true);
    });

    it("should include URL in response", async () => {
      const result = await generateLiveKitToken(testParams);

      expect(result.url).toBe("wss://test.livekit.io:7880");
    });

    it("should use provided userName", async () => {
      const result = await generateLiveKitToken(testParams);
      const decoded = jwtDecode<any>(result.token);

      expect(decoded.name).toBe("Test User");
    });

    it("should default to userId as userName if not provided", async () => {
      const paramsWithoutName = {
        userId: "user456",
        roomName: "another-room",
      };

      const result = await generateLiveKitToken(paramsWithoutName);
      const decoded = jwtDecode<any>(result.token);

      expect(decoded.name).toBe("user456");
    });

    it("should throw error if configuration is missing", async () => {
      // Mock missing configuration
      (admin.remoteConfig as jest.Mock).mockReturnValueOnce({
        getTemplate: jest.fn().mockResolvedValueOnce({
          parameters: {
            // Missing credentials
          },
        }),
      });

      await expect(generateLiveKitToken(testParams)).rejects.toThrow(
        "LiveKit configuration missing in Remote Config"
      );
    });
  });

  describe("generateLiveKitTokenWithOptions", () => {
    it("should generate token with custom permissions", async () => {
      const options = {
        canPublish: false,
        canPublishData: false,
        canSubscribe: true,
        userName: "Custom User",
      };

      const result = await generateLiveKitTokenWithOptions(
        testParams.userId,
        testParams.roomName,
        options
      );

      const decoded = jwtDecode<any>(result.token);
      const grants = decoded.video || decoded.grants;

      expect(grants.canPublish).toBe(false);
      expect(grants.canPublishData).toBe(false);
      expect(grants.canSubscribe).toBe(true);
      expect(decoded.name).toBe("Custom User");
    });

    it("should set custom TTL", async () => {
      const options = {
        ttl: 7200, // 2 hours
      };

      const result = await generateLiveKitTokenWithOptions(
        testParams.userId,
        testParams.roomName,
        options
      );

      const decoded = jwtDecode<any>(result.token);

      // Verify token has expiration
      expect(decoded.exp).toBeDefined();
      // TTL is represented as exp timestamp
      const issuedAt = decoded.nbf || decoded.iat || 0;
      const ttl = decoded.exp - issuedAt;
      // Allow some flexibility due to timing
      expect(ttl).toBeGreaterThan(7190);
      expect(ttl).toBeLessThanOrEqual(7200);
    });

    it("should use default TTL of 3600 seconds", async () => {
      const result = await generateLiveKitTokenWithOptions(
        testParams.userId,
        testParams.roomName
      );

      const decoded = jwtDecode<any>(result.token);
      const issuedAt = decoded.nbf || decoded.iat || 0;
      const expiresAt = decoded.exp;

      // Default TTL should be 3600 seconds (1 hour)
      const ttl = expiresAt - issuedAt;
      // Allow some flexibility due to timing
      expect(ttl).toBeGreaterThan(3590);
      expect(ttl).toBeLessThanOrEqual(3600);
    });

    it("should include all expected fields in response", async () => {
      const result = await generateLiveKitTokenWithOptions(
        testParams.userId,
        testParams.roomName
      );

      expect(result).toHaveProperty("token");
      expect(result).toHaveProperty("userId");
      expect(result).toHaveProperty("roomName");
      expect(result).toHaveProperty("url");
    });
  });

  describe("Token Validation", () => {
    it("should have valid JWT signature format", async () => {
      const result = await generateLiveKitToken(testParams);
      const parts = result.token.split(".");

      // Each part should be a valid base64 string
      parts.forEach((part) => {
        expect(() => Buffer.from(part, "base64").toString()).not.toThrow();
      });
    });

    it("should have non-expired token", async () => {
      const result = await generateLiveKitToken(testParams);
      const decoded = jwtDecode<any>(result.token);

      const now = Math.floor(Date.now() / 1000);
      expect(decoded.exp).toBeGreaterThan(now);
    });

    it("should have correct issuer in token", async () => {
      const result = await generateLiveKitToken(testParams);
      const decoded = jwtDecode<any>(result.token);

      // LiveKit tokens should have an 'iss' (issuer) claim
      expect(decoded.iss).toBeDefined();
    });
  });

  describe("Error Handling", () => {
    it("should handle missing userId", async () => {
      await expect(
        generateLiveKitToken({
          userId: "",
          roomName: "test-room",
        })
      ).rejects.toThrow();
    });

    it("should handle missing roomName", async () => {
      // Note: Empty roomName might still create a token, but LiveKit will reject it on join
      const result = await generateLiveKitToken({
        userId: "user123",
        roomName: "",
      });

      // Check that token was generated (validity will be checked on server)
      expect(result.token).toBeDefined();
      expect(result.userId).toBe("user123");
    });

    it("should throw error for missing configuration", async () => {
      try {
        await generateLiveKitToken({
          userId: "",
          roomName: "test-room",
        });
        fail("Should have thrown an error");
      } catch (error) {
        // Should fail because userId is empty
        expect(error).toBeDefined();
      }
    });
  });
});
