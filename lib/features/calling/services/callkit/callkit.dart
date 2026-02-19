// CallKit Integration for iOS
//
// This module provides native iOS CallKit integration for:
// - Displaying incoming call UI when app is killed/background
// - Native outgoing call UI
// - VoIP push notification handling
// - Audio session management
//
// ## Usage
//
// ```dart
// // Initialize in your main app
// final callKitService = CallKitService();
//
// // Report incoming call
// await callKitService.reportIncomingCall(
//   callerName: 'John Doe',
//   callerId: 'user123',
// );
//
// // Listen for call actions
// callKitService.callActions.listen((action) {
//   switch (action.action) {
//     case 'answerCall':
//       // User answered from native UI
//       break;
//     case 'endCall':
//       // User ended call from native UI
//       break;
//   }
// });
// ```

export 'callkit_service.dart';
