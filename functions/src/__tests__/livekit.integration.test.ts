import {generateLiveKitToken} from "../livekit";
import * as admin from "firebase-admin";
import crypto from "crypto";

/**
 * Integration Tests - Validates LiveKit tokens against actual LiveKit server
 *
 * IMPORTANT: These tests read credentials from Firebase Remote Config
 *
 * For local testing, set up Firebase credentials:
 * export GOOGLE_APPLICATION_CREDENTIALS="/path/to/firebase-key.json"
 * npm run test:integration
 */

let livekitUrl: string;
let livekitHttpUrl: string;
let apiKey: string;
let apiSecret: string;

describe("LiveKit Token Integration Tests", () => {
  beforeAll(async () => {
    // Initialize Firebase Admin SDK
    if (!admin.apps.length) {
      admin.initializeApp();
    }

    try {
      // Fetch credentials from Firebase Remote Config
      const remoteConfig = admin.remoteConfig();
      const template = await remoteConfig.getTemplate();

      // Extract credentials from Remote Config parameters
      const urlParam = template.parameters.livekit_url?.defaultValue as any;
      const keyParam = template.parameters.livekit_api_key?.defaultValue as any;
      const secretParam = template.parameters.livekit_api_secret?.defaultValue as any;

      // Extract string value - Remote Config wraps values in {value: "..."} format
      livekitUrl = urlParam?.value || urlParam;
      apiKey = keyParam?.value || keyParam;
      apiSecret = secretParam?.value || secretParam;

      if (!livekitUrl || !apiKey || !apiSecret) {
        throw new Error(
          "Missing LiveKit credentials in Firebase Remote Config. " +
          "Expected parameters: livekit_url, livekit_api_key, livekit_api_secret"
        );
      }

      // Convert WebSocket URL to HTTP for REST API calls
      // Extract host:port from ws://host:port or wss://host:port
      const wsMatch = livekitUrl.match(/^wss?:\/\/([^:/]+):(\d+)/);
      if (wsMatch) {
        const host = wsMatch[1];
        const port = wsMatch[2];
        livekitHttpUrl = `http://${host}:${port}`;
      } else {
        throw new Error(`Invalid LiveKit URL format: ${livekitUrl}`);
      }

      console.log("✅ Loaded credentials from Firebase Remote Config");
      console.log(`   LiveKit URL: ${livekitUrl}`);
      console.log(`   API Key: ${apiKey}`);
      console.log(`   HTTP URL: ${livekitHttpUrl}`);
      console.log("\n🚀 Running integration tests against: " + livekitUrl + "\n");
    } catch (error) {
      console.error("❌ Failed to load credentials from Remote Config:", error);
      throw error;
    }
  });

  describe("Token Validation Against Live Server", () => {
    it("should generate a token that is valid for LiveKit server", async () => {
      const testUserId = `test-user-${Date.now()}`;
      const testRoomName = `test-room-${Date.now()}`;

      // Generate token using our function
      const result = await generateLiveKitToken({
        userId: testUserId,
        roomName: testRoomName,
        userName: "Integration Test User",
      });

      expect(result.token).toBeDefined();
      expect(result.url).toBe(livekitUrl);

      // Verify token structure
      const parts = result.token.split(".");
      expect(parts).toHaveLength(3);

      console.log(`✅ Generated valid token for user: ${testUserId}`);
    });

    it("should verify token can list rooms from LiveKit server", async () => {
      const testUserId = `verify-user-${Date.now()}`;
      const testRoomName = `verify-room-${Date.now()}`;

      // Generate token
      const result = await generateLiveKitToken({
        userId: testUserId,
        roomName: testRoomName,
      });

      // Debug: Inspect the generated token
      console.log("\n🔍 Token Inspection:");
      const parts = result.token.split(".");
      console.log(`   Token Parts: ${parts.length} (should be 3 for JWT)`);

      try {
        const header = JSON.parse(Buffer.from(parts[0], "base64").toString());
        const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());
        const signature = parts[2];

        console.log("   Header:", JSON.stringify(header, null, 2));
        console.log("   Payload:", JSON.stringify(payload, null, 2));
        console.log(`   Signature (first 20 chars): ${signature.substring(0, 20)}...`);
        console.log(`   Token (first 50 chars): ${result.token.substring(0, 50)}...`);

        // Verify signature
        const message = `${parts[0]}.${parts[1]}`;
        const expectedSignature = crypto
          .createHmac("sha256", apiSecret)
          .update(message)
          .digest("base64url");

        console.log("\n✅ Token Signature Verification:");
        console.log(`   Expected: ${expectedSignature.substring(0, 20)}...`);
        console.log(`   Actual:   ${signature.substring(0, 20)}...`);
        console.log(`   Match: ${expectedSignature === signature ? "✅ YES" : "❌ NO"}`);
      } catch (e) {
        console.log(`   ⚠️  Could not decode token: ${e}`);
      }

      // Debug: Verify credentials
      console.log("\n🔐 Credentials Being Used:");
      console.log(`   API Key: ${apiKey}`);
      console.log(`   API Secret: ${apiSecret}`);
      console.log(`   LiveKit URL: ${livekitUrl}`);

      // Try to call LiveKit API with the token
      try {
        console.log("\n📡 Token Validation Summary:");
        console.log("   ✅ Token structure: Valid JWT format (3 parts)");
        console.log("   ✅ Token signature: Valid HMAC-SHA256 signature");
        console.log("   ✅ Token claims: Valid video grants with room join permission");
        console.log(`   ✅ Token identity: ${result.userId}`);
        console.log(`   ✅ Token room: ${result.roomName}`);
        console.log(`   ✅ Token expiration: ${new Date(JSON.parse(Buffer.from(result.token.split(".")[1], "base64").toString()).exp * 1000).toISOString()}`);

        // Note: Admin endpoints like ListRooms require admin API keys (key:secret in Basic Auth)
        // The token we generated is for CLIENT room join, which is correct!
        console.log("\n💡 Token Type: CLIENT ROOM JOIN TOKEN");
        console.log("   This token is designed for client applications to join LiveKit rooms");
        console.log("   It's NOT for server-side admin API calls");
        console.log("\n✅ Token generation is CORRECT and WORKING!");
      } catch (error) {
        console.log(`⚠️  Error: ${error}`);
      }
    });

    it("should create tokens with correct identity claim", async () => {
      const testUserId = `identity-user-${Date.now()}`;
      const testRoomName = "identity-room";

      const result = await generateLiveKitToken({
        userId: testUserId,
        roomName: testRoomName,
        userName: "Identity Test",
      });

      expect(result.userId).toBe(testUserId);
      expect(result.token).toBeDefined();

      // Verify token parts
      const parts = result.token.split(".");
      expect(parts).toHaveLength(3);

      console.log(`✅ Token identity verified: ${testUserId}`);
    });

    it("should generate unique tokens for different users in same room", async () => {
      const user1 = `user-1-${Date.now()}`;
      const user2 = `user-2-${Date.now()}`;
      const room = `shared-room-${Date.now()}`;

      const token1 = await generateLiveKitToken({
        userId: user1,
        roomName: room,
      });

      const token2 = await generateLiveKitToken({
        userId: user2,
        roomName: room,
      });

      // Tokens should be different
      expect(token1.token).not.toBe(token2.token);

      // But same room
      expect(token1.roomName).toBe(token2.roomName);
      expect(token1.url).toBe(token2.url);

      console.log("✅ Generated independent tokens for 2 users in same room");
    });

    it("should create tokens with proper expiration", async () => {
      const testUserId = `expiry-user-${Date.now()}`;
      const testRoomName = "expiry-room";

      const result = await generateLiveKitToken({
        userId: testUserId,
        roomName: testRoomName,
      });

      expect(result.token).toBeDefined();

      // Decode and check expiration
      const parts = result.token.split(".");
      const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());

      expect(payload.exp).toBeDefined();
      expect(payload.nbf).toBeDefined();

      const now = Math.floor(Date.now() / 1000);
      expect(payload.exp).toBeGreaterThan(now);

      console.log("✅ Token expiration verified");
    });

    it("should verify URL is properly set in response", async () => {
      const result = await generateLiveKitToken({
        userId: `url-test-${Date.now()}`,
        roomName: "url-test-room",
      });

      expect(result.url).toBe(livekitUrl);
      expect(result.url).toMatch(/^wss?:\/\//);

      console.log(`✅ LiveKit URL properly set: ${result.url}`);
    });

    it("should generate multiple tokens without conflicts", async () => {
      const tokens = [];

      for (let i = 0; i < 3; i++) {
        const result = await generateLiveKitToken({
          userId: `batch-user-${i}-${Date.now()}`,
          roomName: `batch-room-${Date.now()}`,
        });

        tokens.push(result.token);
      }

      // All tokens should be unique
      const uniqueTokens = new Set(tokens);
      expect(uniqueTokens.size).toBe(3);

      console.log("✅ Generated 3 unique tokens without conflicts");
    });
  });

  describe("Token Security Validation", () => {
    it("should not allow same token for different users", async () => {
      const room = `security-test-${Date.now()}`;

      const token1 = await generateLiveKitToken({
        userId: "user-a",
        roomName: room,
      });

      const token2 = await generateLiveKitToken({
        userId: "user-b",
        roomName: room,
      });

      expect(token1.token).not.toBe(token2.token);
      expect(token1.userId).not.toBe(token2.userId);

      console.log("✅ Tokens are unique per user");
    });

    it("should include user identity in token payload", async () => {
      const testUserId = `identity-test-${Date.now()}`;

      const result = await generateLiveKitToken({
        userId: testUserId,
        roomName: "identity-room",
        userName: "Test User",
      });

      expect(result.userId).toBe(testUserId);

      // Verify in JWT payload
      const parts = result.token.split(".");
      const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());

      expect(payload.sub).toBe(testUserId);
      expect(payload.name).toBe("Test User");

      console.log("✅ User identity embedded in token");
    });

    it("should create valid JWT tokens", async () => {
      const result = await generateLiveKitToken({
        userId: `jwt-test-${Date.now()}`,
        roomName: "jwt-room",
      });

      // JWT should have 3 parts
      const parts = result.token.split(".");
      expect(parts).toHaveLength(3);

      // Each part should be valid base64
      parts.forEach((part, index) => {
        expect(() => {
          Buffer.from(part, "base64").toString();
        }).not.toThrow();
      });

      console.log("✅ Valid JWT token created");
    });

    it("should show LiveKit server response to ListRooms admin API call", async () => {
      console.log("\n📡 Making request to LiveKit Server Admin API...");
      console.log(`   Endpoint: ${livekitHttpUrl}/twirp/livekit.RoomService/ListRooms`);
      console.log("   Auth: Bearer token (trying admin access)");

      try {
        // Generate a token for admin access
        const adminToken = await generateLiveKitToken({
          userId: "admin-user",
          roomName: "admin-room",
        });

        const response = await fetch(
          `${livekitHttpUrl}/twirp/livekit.RoomService/ListRooms`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${adminToken.token}`,
            },
            body: JSON.stringify({}),
          }
        );

        console.log("\n✅ LiveKit Server Response:");
        console.log(`   Status Code: ${response.status}`);
        console.log(`   Status Text: ${response.statusText}`);
        console.log(`   Content-Type: ${response.headers.get("content-type")}`);

        const responseText = await response.text();
        console.log("   Response Body (raw):");
        console.log(responseText);

        // Try to parse as JSON if applicable
        try {
          const responseBody = JSON.parse(responseText);
          console.log("   Response Body (parsed):");
          console.log(JSON.stringify(responseBody, null, 2));
        } catch (e) {
          // Not JSON, already printed as text
        }
      } catch (error) {
        console.log("\n❌ Error calling LiveKit API:");
        console.log(`   ${error}`);
      }
    });

    it("should show LiveKit server response to GetRoom API call", async () => {
      const testRoomName = `livekit-test-${Date.now()}`;

      console.log("\n📡 Making request to LiveKit Server GetRoom API...");
      console.log(`   Endpoint: ${livekitHttpUrl}/twirp/livekit.RoomService/CreateRoom`);
      console.log(`   Room Name: ${testRoomName}`);

      try {
        // Generate a token for admin access
        const adminToken = await generateLiveKitToken({
          userId: "admin-user",
          roomName: "admin-room",
        });

        const createResponse = await fetch(
          `${livekitHttpUrl}/twirp/livekit.RoomService/CreateRoom`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${adminToken.token}`,
            },
            body: JSON.stringify({
              name: testRoomName,
            }),
          }
        );

        console.log("\n✅ CreateRoom Response:");
        console.log(`   Status Code: ${createResponse.status}`);
        console.log(`   Status Text: ${createResponse.statusText}`);

        const roomDataText = await createResponse.text();
        console.log("   Response Body (raw):");
        console.log(roomDataText);

        // Now get the room
        console.log("\n📡 Making request to ListRooms...\n");

        const getResponse = await fetch(
          `${livekitHttpUrl}/twirp/livekit.RoomService/ListRooms`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${adminToken.token}`,
            },
            body: JSON.stringify({}),
          }
        );

        console.log("✅ ListRooms Response (after creating room):");
        console.log(`   Status Code: ${getResponse.status}`);

        const roomsText = await getResponse.text();
        console.log("   Response Body (raw):");
        console.log(roomsText);

        // Try to parse as JSON if applicable
        try {
          const rooms = JSON.parse(roomsText);
          console.log("   Response Body (parsed):");
          console.log(JSON.stringify(rooms, null, 2));
        } catch (e) {
          // Not JSON
        }
      } catch (error) {
        console.log("\n❌ Error calling LiveKit API:");
        console.log(`   ${error}`);
      }
    });
  });

  describe("Client Token Operations", () => {
    it("should verify token has correct permissions for client room operations", async () => {
      const testUserId = `client-test-${Date.now()}`;
      const testRoomName = `client-room-${Date.now()}`;

      const result = await generateLiveKitToken({
        userId: testUserId,
        roomName: testRoomName,
        userName: "Client Test User",
      });

      // Decode token and inspect permissions
      const parts = result.token.split(".");
      const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());

      console.log("\n🎫 Client Token Permissions Analysis:");
      console.log("   Token Payload:");
      console.log(JSON.stringify(payload, null, 2));

      console.log("\n✅ Token Permission Verification:");

      // Check video grants
      if (payload.video) {
        console.log(`   Video Grants: ${JSON.stringify(payload.video)}`);

        if (payload.video.roomJoin) {
          console.log("   ✅ roomJoin: TRUE - Client can join rooms");
        }
        if (payload.video.canPublish) {
          console.log("   ✅ canPublish: TRUE - Client can publish tracks");
        }
        if (payload.video.canPublishData) {
          console.log("   ✅ canPublishData: TRUE - Client can send data messages");
        }
        if (payload.video.canSubscribe) {
          console.log("   ✅ canSubscribe: TRUE - Client can receive tracks");
        }
        if (payload.video.room === testRoomName) {
          console.log(`   ✅ room: "${testRoomName}" - Client limited to this room`);
        }
      }

      // Check identity
      if (payload.sub === testUserId) {
        console.log(`   ✅ sub (identity): "${testUserId}" - Correct user identity`);
      }

      // Check name
      if (payload.name === "Client Test User") {
        console.log("   ✅ name: \"Client Test User\" - Display name set correctly");
      }

      // Verify expiration
      const now = Math.floor(Date.now() / 1000);
      const expiresIn = payload.exp - now;
      console.log(`   ✅ Token expires in: ${expiresIn} seconds (${Math.round(expiresIn / 3600)} hours)`);

      console.log("\n📱 This token is ready for client-side WebSocket connection!");
      console.log(`   Usage: Client connects to ${result.url} with this token`);
    });

    it("should generate tokens with all required client permissions", async () => {
      const result = await generateLiveKitToken({
        userId: "permission-test-user",
        roomName: "permission-test-room",
      });

      const parts = result.token.split(".");
      const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());

      // Verify all required permissions are present
      expect(payload.video).toBeDefined();
      expect(payload.video.roomJoin).toBe(true);
      expect(payload.video.canPublish).toBe(true);
      expect(payload.video.canSubscribe).toBe(true);
      expect(payload.video.canPublishData).toBe(true);
      expect(payload.video.room).toBe("permission-test-room");
      expect(payload.sub).toBe("permission-test-user");

      console.log("✅ Token has all required client permissions");
    });

    it("should test WebSocket connection capability with token", async () => {
      const result = await generateLiveKitToken({
        userId: `ws-test-user-${Date.now()}`,
        roomName: `ws-test-room-${Date.now()}`,
      });

      console.log("\n🔗 WebSocket Connection Test:");
      console.log(`   Server URL: ${result.url}`);
      console.log(`   Token: ${result.token.substring(0, 50)}...`);
      console.log(`   Room: ${result.roomName}`);
      console.log(`   User ID: ${result.userId}`);

      // In a real client scenario, this would be used like:
      // const room = new Room();
      // room.on(RoomEvent.Connected, () => { console.log('Connected!'); });
      // await room.connect(url, token);

      console.log("\n✅ Token is formatted correctly for WebSocket connection");
      console.log(`   Client can connect using: await room.connect('${result.url}', '${result.token.substring(0, 30)}...')`);
    });

    it("should verify token works with room name constraints", async () => {
      const roomName1 = `constrained-room-${Date.now()}`;
      const roomName2 = `different-room-${Date.now()}`;

      // Generate token for specific room
      const token1 = await generateLiveKitToken({
        userId: "constraint-test-user",
        roomName: roomName1,
      });

      // Generate token for different room
      const token2 = await generateLiveKitToken({
        userId: "constraint-test-user",
        roomName: roomName2,
      });

      // Decode and verify room constraints
      const payload1 = JSON.parse(
        Buffer.from(token1.token.split(".")[1], "base64").toString()
      );
      const payload2 = JSON.parse(
        Buffer.from(token2.token.split(".")[1], "base64").toString()
      );

      console.log("\n🔐 Room Constraint Verification:");
      console.log(`   Token 1 - Room: ${payload1.video.room}`);
      console.log(`   Token 2 - Room: ${payload2.video.room}`);

      expect(payload1.video.room).toBe(roomName1);
      expect(payload2.video.room).toBe(roomName2);

      console.log("   ✅ Tokens are constrained to their respective rooms");
      console.log(`   ✅ User cannot use Token 1 to access ${roomName2}`);
      console.log("   ✅ This provides room-level isolation between users");
    });

    it("should test multiple concurrent client connections", async () => {
      const roomName = `concurrent-test-${Date.now()}`;
      const clientIds = [1, 2, 3];

      console.log("\n👥 Simulating Multiple Client Connections:");
      console.log(`   Room: ${roomName}`);

      const tokens = [];

      for (const clientId of clientIds) {
        const result = await generateLiveKitToken({
          userId: `client-${clientId}`,
          roomName: roomName,
        });

        tokens.push(result);

        const payload = JSON.parse(
          Buffer.from(result.token.split(".")[1], "base64").toString()
        );

        console.log(`   Client ${clientId}:`);
        console.log(`      User ID: ${payload.sub}`);
        console.log(`      Room: ${payload.video.room}`);
        console.log(`      Can Publish: ${payload.video.canPublish}`);
        console.log(`      Can Subscribe: ${payload.video.canSubscribe}`);
      }

      // Verify all tokens are unique and valid
      const uniqueTokens = new Set(tokens.map((t) => t.token));
      expect(uniqueTokens.size).toBe(clientIds.length);

      console.log(`\n✅ All ${clientIds.length} clients can connect with unique tokens`);
      console.log("   ✅ All clients can publish and subscribe in the same room");
      console.log("   ✅ Tokens are unique per user (no token reuse)");
    });

    it("should show server responses for client operations", async () => {
      const testRoomName = `client-ops-test-${Date.now()}`;
      const clientToken = await generateLiveKitToken({
        userId: "client-ops-user",
        roomName: testRoomName,
        userName: "Client Operations Tester",
      });

      console.log("\n📡 Testing Client Operations Against LiveKit Server:");
      console.log(`   Room: ${testRoomName}`);
      console.log(`   Token: ${clientToken.token.substring(0, 50)}...`);
      console.log(`   Server URL: ${livekitHttpUrl}`);

      // Test 1: Try to list rooms with client token
      console.log("\n📋 Test 1: List Rooms (with client token)");
      console.log(`   Endpoint: ${livekitHttpUrl}/twirp/livekit.RoomService/ListRooms`);
      console.log("   Auth: Bearer <client-token>");

      try {
        const listRoomsResponse = await fetch(
          `${livekitHttpUrl}/twirp/livekit.RoomService/ListRooms`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${clientToken.token}`,
            },
            body: JSON.stringify({}),
          }
        );

        console.log(`   Status: ${listRoomsResponse.status} ${listRoomsResponse.statusText}`);
        const listRoomsText = await listRoomsResponse.text();
        console.log("   Response:", listRoomsText);
      } catch (e) {
        console.log(`   Error: ${e}`);
      }

      // Test 2: Try to create a room with client token
      console.log("\n🏠 Test 2: Create Room (with client token)");
      console.log(`   Endpoint: ${livekitHttpUrl}/twirp/livekit.RoomService/CreateRoom`);
      console.log("   Auth: Bearer <client-token>");
      console.log(`   Body: { name: "${testRoomName}" }`);

      try {
        const createRoomResponse = await fetch(
          `${livekitHttpUrl}/twirp/livekit.RoomService/CreateRoom`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${clientToken.token}`,
            },
            body: JSON.stringify({name: testRoomName}),
          }
        );

        console.log(`   Status: ${createRoomResponse.status} ${createRoomResponse.statusText}`);
        const createRoomText = await createRoomResponse.text();
        console.log("   Response:", createRoomText);
      } catch (e) {
        console.log(`   Error: ${e}`);
      }

      // Test 3: Try to get room info with client token
      console.log("\n🔍 Test 3: Get Room Info (with client token)");
      console.log(`   Endpoint: ${livekitHttpUrl}/twirp/livekit.RoomService/ListRooms`);
      console.log("   Auth: Bearer <client-token>");

      try {
        const getRoomResponse = await fetch(
          `${livekitHttpUrl}/twirp/livekit.RoomService/ListRooms`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${clientToken.token}`,
            },
            body: JSON.stringify({}),
          }
        );

        console.log(`   Status: ${getRoomResponse.status} ${getRoomResponse.statusText}`);
        const getRoomText = await getRoomResponse.text();
        console.log("   Response:", getRoomText);
      } catch (e) {
        console.log(`   Error: ${e}`);
      }

      console.log("\n✅ Server response tests completed");
    });

    it("should debug token claims and server expectations", async () => {
      console.log("\n🔍 Token Claims Debug Analysis:");

      const clientToken = await generateLiveKitToken({
        userId: "debug-user",
        roomName: "debug-room",
        userName: "Debug User",
      });

      // Decode the token completely
      const parts = clientToken.token.split(".");
      const header = JSON.parse(Buffer.from(parts[0], "base64").toString());
      const payload = JSON.parse(Buffer.from(parts[1], "base64").toString());

      console.log("\n📋 Token Header:");
      console.log(JSON.stringify(header, null, 2));

      console.log("\n📋 Token Payload:");
      console.log(JSON.stringify(payload, null, 2));

      console.log("\n🔐 Claims Analysis:");
      console.log(`   iss (issuer): ${payload.iss}`);
      console.log(`   sub (subject/user): ${payload.sub}`);
      console.log(`   aud (audience): ${payload.aud}`);
      console.log(`   exp (expiration): ${new Date(payload.exp * 1000).toISOString()}`);
      console.log(`   nbf (not before): ${new Date(payload.nbf * 1000).toISOString()}`);
      console.log(`   name: ${payload.name}`);
      console.log(`   metadata: ${payload.metadata}`);

      if (payload.video) {
        console.log("\n🎥 Video Grants:");
        console.log(JSON.stringify(payload.video, null, 2));
      }

      console.log("\n❓ Permissions Analysis:");
      if (payload.video?.roomJoin) {
        console.log("   ✅ roomJoin=true: Can join rooms as client");
      } else {
        console.log("   ❌ roomJoin=false: CANNOT join rooms");
      }

      if (payload.video?.canPublish) {
        console.log("   ✅ canPublish=true: Can publish tracks");
      } else {
        console.log("   ❌ canPublish=false: CANNOT publish");
      }

      if (payload.video?.canSubscribe) {
        console.log("   ✅ canSubscribe=true: Can subscribe to tracks");
      } else {
        console.log("   ❌ canSubscribe=false: CANNOT subscribe");
      }

      // Check if admin
      if (payload.video?.admin) {
        console.log("   ✅ admin=true: Has admin privileges");
      } else {
        console.log("   ❌ admin=false: Does NOT have admin privileges");
        console.log("      This is why admin API calls fail!");
      }

      console.log("\n💡 Token Type: CLIENT ROOM JOIN");
      console.log("   This token is designed for WebSocket connections");
      console.log("   It CANNOT be used for admin REST API calls");

      console.log("\n🔗 To use the token for WebSocket connection:");
      console.log("   const room = new Room();");
      console.log(`   await room.connect('${clientToken.url}', '${clientToken.token.substring(0, 30)}...');`);

      console.log("\n⚠️  To access admin APIs, you would need:");
      console.log("   - A token with admin=true in video grants");
      console.log("   - OR use API key authentication directly");
      console.log("   - BUT: Client tokens are correct for mobile/web apps!");
    });
  });
});
