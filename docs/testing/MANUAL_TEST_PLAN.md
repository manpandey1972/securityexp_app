# GreenHive App — Manual Test Plan

> **Purpose**: Pre-release checklist to verify all features work correctly on iOS, Android, and Web.
> **Last Updated**: February 10, 2026

---

## How To Use This Document

- **Before each release**, walk through every section below.
- Mark each test case: ✅ Pass | ❌ Fail | ⏭️ Skipped (with reason)
- For failures, note the device, OS version, and steps to reproduce.
- Platform columns: **iOS** / **Android** / **Web** — mark N/A where a feature doesn't apply.

---

## Table of Contents

1. [App Launch & Initialization](#1-app-launch--initialization)
2. [Authentication — Phone Login](#2-authentication--phone-login)
3. [Biometric Authentication](#3-biometric-authentication)
4. [Onboarding](#4-onboarding)
5. [Home & Navigation](#5-home--navigation)
6. [Expert Discovery & Profile](#6-expert-discovery--profile)
7. [Chat — Conversations List](#7-chat--conversations-list)
8. [Chat — Messaging](#8-chat--messaging)
9. [Chat — Media Messages](#9-chat--media-messages)
10. [Chat — Audio Recording & Playback](#10-chat--audio-recording--playback)
11. [Chat — Document Sharing](#11-chat--document-sharing)
12. [Audio & Video Calling](#12-audio--video-calling)
13. [Call History](#13-call-history)
14. [User Profile & Settings](#14-user-profile--settings)
15. [Photo Backup](#15-photo-backup)
16. [Ratings & Reviews](#16-ratings--reviews)
17. [Support & Help Center](#17-support--help-center)
18. [Admin Panel](#18-admin-panel)
19. [Push Notifications](#19-push-notifications)
20. [Presence & Online Status](#20-presence--online-status)
21. [Caching & Storage](#21-caching--storage)
22. [Offline & Error Handling](#22-offline--error-handling)
23. [Performance & Memory](#23-performance--memory)
24. [Platform-Specific Behavior](#24-platform-specific-behavior)
25. [Accessibility & Edge Cases](#25-accessibility--edge-cases)

---

## 1. App Launch & Initialization

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 1.1 | Cold start — logged out | Install fresh, open app | Splash screen → Phone auth screen within 3s | | | |
| 1.2 | Cold start — logged in | Open app with existing session | Splash → Biometric (if enabled) → Home | | | |
| 1.3 | Cold start — logged in, no biometric | Open app, biometric disabled | Splash → Home directly | | | |
| 1.4 | App resume from background | Put app in background, return | App resumes without re-auth, state preserved | | | |
| 1.5 | App killed and reopened | Force-kill app, reopen | Same as cold start (1.2 or 1.3) | | | |
| 1.6 | Deep link — cold start | Tap notification when app is killed | App launches and navigates to correct screen | | | N/A |
| 1.7 | Firebase initialization | First launch | No crashes, analytics/crashlytics initialized | | | |

---

## 2. Authentication — Phone Login

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 2.1 | Enter valid phone number | Enter 10-digit number, tap Send OTP | OTP sent, navigates to verification screen | | | |
| 2.2 | Enter invalid phone number | Enter too short/long number | Validation error shown, no OTP sent | | | |
| 2.3 | Enter correct OTP | Enter 6-digit OTP received via SMS | Successful login, navigate to onboarding (new) or home (existing) | | | |
| 2.4 | Enter incorrect OTP | Enter wrong 6 digits | Error message: "Invalid verification code" | | | |
| 2.5 | OTP auto-fill (Android) | Receive OTP via SMS | OTP auto-fills in the input field | N/A | | N/A |
| 2.6 | Resend OTP | Wait for timer, tap Resend | New OTP sent, timer resets | | | |
| 2.7 | OTP expiration | Wait > 2 minutes, enter OTP | Error: session expired, prompt to resend | | | |
| 2.8 | Country code selection | Tap country code, select different country | Country code updates, phone format adjusts | | | |
| 2.9 | New user registration | Login with new phone number | Redirected to onboarding after OTP | | | |
| 2.10 | Existing user login | Login with registered number | Redirected to home after OTP | | | |
| 2.11 | Rate limiting | Attempt multiple OTP sends rapidly | Rate limit message shown after threshold | | | |

---

## 3. Biometric Authentication

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 3.1 | Enable biometric | Profile → Settings → Toggle biometric on | Biometric prompt appears, setting saved | | | N/A |
| 3.2 | Disable biometric | Profile → Settings → Toggle biometric off | Setting saved, next launch skips biometric | | | N/A |
| 3.3 | Face ID unlock (iOS) | Open app with biometric enabled | Face ID prompt, successful unlock → Home | | N/A | N/A |
| 3.4 | Fingerprint unlock (Android) | Open app with biometric enabled | Fingerprint prompt, successful unlock → Home | N/A | | N/A |
| 3.5 | Biometric failure — retry | Fail biometric, tap retry | Prompt shown again | | | N/A |
| 3.6 | Biometric cancelled | Cancel biometric prompt | App stays on lock screen, retry available | | | N/A |
| 3.7 | Device without biometric | Enable biometric on device without sensor | Option hidden or graceful fallback | | | N/A |

---

## 4. Onboarding

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 4.1 | Complete onboarding — new user | Fill name, upload photo, select skills | Profile created, navigated to home | | | |
| 4.2 | Skip optional fields | Enter only name, skip photo/skills | Profile created with defaults | | | |
| 4.3 | Upload profile picture | Tap avatar, choose from gallery | Image cropped, preview shown | | | |
| 4.4 | Take profile photo | Tap avatar, choose camera | Camera opens, photo captured, preview shown | | | N/A |
| 4.5 | Select skills/interests | Tap skill chips on skill selection | Selected skills highlighted, saved to profile | | | |
| 4.6 | Select language | Choose preferred language | Language preference saved | | | |
| 4.7 | Validation — empty name | Try to continue without name | Validation error shown | | | |

---

## 5. Home & Navigation

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 5.1 | Bottom navigation tabs | Tap each tab: Home, Chats, Calls, Profile | Corresponding screen loads correctly | | | |
| 5.2 | Home screen loads | Navigate to Home tab | Expert cards, products, carousel load | | | |
| 5.3 | Pull to refresh | Pull down on home screen | Data refreshes, loading indicator shown | | | |
| 5.4 | Upload status indicator | Send media in chat, go to Home | Upload progress indicator visible in app bar | | | |
| 5.5 | Search experts | Tap search/filter on home | Search results update as typing | | | |
| 5.6 | Product listing | Scroll to products section | Products display with name, price, image | | | |
| 5.7 | Image carousel | Swipe home carousel | Images cycle smoothly, indicators update | | | |

---

## 6. Expert Discovery & Profile

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 6.1 | View expert card | Home → scroll to experts | Expert cards show name, photo, skills, rating | | | |
| 6.2 | Tap expert card | Tap on an expert | Expert detail page opens | | | |
| 6.3 | Expert detail — info | View expert detail page | Shows bio, skills, languages, rating, reviews | | | |
| 6.4 | Start chat from expert | Tap "Message" on expert detail | Chat room created/opened | | | |
| 6.5 | Call from expert profile | Tap "Call" on expert detail | Call initiated (audio or video) | | | |
| 6.6 | View expert reviews | Scroll to reviews section | Reviews paginate correctly with star ratings | | | |
| 6.7 | Expert not available | View expert who is offline | Appropriate status indicator shown | | | |

---

## 7. Chat — Conversations List

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 7.1 | Chat list loads | Navigate to Chats tab | All conversations display with latest message | | | |
| 7.2 | Unread badge count | Receive message while on different screen | Unread dot/count on chat item and tab | | | |
| 7.3 | Last message preview | View chat list | Shows truncated last message text/type | | | |
| 7.4 | Timestamp display | View chat list | Relative time (now, 5m, 1h, Yesterday, date) | | | |
| 7.5 | Tap to open chat | Tap a conversation | Chat conversation screen opens | | | |
| 7.6 | Empty state | New user with no chats | Empty state illustration and message | | | |
| 7.7 | Search conversations | Tap search icon | Filter conversations by name/content | | | |
| 7.8 | Online status indicator | Check chat list | Online users show green dot | | | |

---

## 8. Chat — Messaging

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 8.1 | Send text message | Type message, tap send | Message appears in chat, sent indicator shown | | | |
| 8.2 | Receive text message | Other user sends message | Message appears in real-time, notification sound | | | |
| 8.3 | Long text message | Send 500+ character message | Message renders correctly with full text | | | |
| 8.4 | Empty message — blocked | Tap send with empty input | Send button disabled or no action | | | |
| 8.5 | Message timestamps | View messages | Grouped by date, time shown per message | | | |
| 8.6 | Send/delivered/read status | Send message, other user reads | Tick marks update (sent → delivered → read) | | | |
| 8.7 | Swipe to reply | Swipe right on a message | Reply preview appears above input | | | |
| 8.8 | Reply preview display | Send reply message | Original message shown as quote above reply | | | |
| 8.9 | Cancel reply | Tap X on reply preview | Reply preview dismissed | | | |
| 8.10 | Edit message | Long press → Edit | Message text updates, "edited" label shown | | | |
| 8.11 | Delete message | Long press → Delete | Message removed, "deleted" placeholder shown | | | |
| 8.12 | Copy message text | Long press → Copy | Text copied to clipboard | | | |
| 8.13 | Link detection | Send URL in message | Link is tappable, opens browser/in-app | | | |
| 8.14 | Link preview | Send message with URL | Link preview card with title/image loads | | | |
| 8.15 | Scroll to bottom | Scroll up in long chat, tap scroll-down button | Scrolls to most recent messages | | | |
| 8.16 | Pagination — load older messages | Scroll to top of chat | Older messages load with spinner | | | |
| 8.17 | Tap on replied message | Tap the quoted reply bubble | Scrolls to and highlights original message | | | |
| 8.18 | Chat app bar — user info | Check chat top bar | Shows user name, photo, online status | | | |
| 8.19 | Profanity filter | Send message with profanity | Message blocked or filtered | | | |

---

## 9. Chat — Media Messages

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 9.1 | Send image from gallery | Tap attachment → Gallery → Select image | Image uploads with progress, thumbnail shown | | | |
| 9.2 | Send image from camera | Tap attachment → Camera → Capture | Photo captured, uploaded, displayed in chat | | | N/A |
| 9.3 | Send multiple images | Select multiple images from gallery | All images upload and display | | | |
| 9.4 | Image preview — tap to expand | Tap image in chat | Full-screen image viewer opens | | | |
| 9.5 | Image preview — zoom/pan | Pinch-zoom on full-screen image | Smooth zoom and pan gesture | | | |
| 9.6 | Send video | Tap attachment → select video | Video uploads with progress, preview shown | | | |
| 9.7 | Inline video preview | View video message in chat | Video thumbnail with play button | | | |
| 9.8 | Tap video — playback | Tap play on video message | Video plays with controls, cached if available | | | |
| 9.9 | Video — expand to full-screen | Tap expand button on video | Full-screen video player | | | |
| 9.10 | Media download button | Tap download on received media | File saved to device, success toast | | | |
| 9.11 | Upload progress indicator | Send large media file | Progress bar visible on message bubble | | | |
| 9.12 | Upload failure | Send media on poor connection | Error state on bubble, retry option | | | |
| 9.13 | Cached media — instant load | Re-open chat with media | Previously loaded images/videos load instantly from cache | | | |
| 9.14 | Large file handling | Send very large video (>100 MB) | Size warning or compression applied | | | |

---

## 10. Chat — Audio Recording & Playback

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 10.1 | Record audio message | Tap & hold record button | Recording indicator shows, duration counts up | | | |
| 10.2 | Send audio recording | Release record button | Audio uploads, inline player shown in chat | | | |
| 10.3 | Cancel audio recording | Slide away while recording | Recording cancelled, nothing sent | | | |
| 10.4 | Play audio — inline | Tap play on audio message | Audio plays with progress bar, duration shown | | | |
| 10.5 | Pause/resume audio | Tap play, then tap pause | Playback pauses, resumes from same position | | | |
| 10.6 | Audio playback speed | Audio plays at correct speed | No distortion, clear sound | | | |
| 10.7 | Audio — cached playback (mobile) | Play audio that was previously played | Plays instantly from cache (no delay) | | | N/A |
| 10.8 | Audio — network playback (web) | Play audio on web | Plays from network URL, no DeviceFileSource error | N/A | N/A | |
| 10.9 | Audio — speaker output | Play audio message | Audio comes through speaker (not earpiece) | | | N/A |
| 10.10 | Microphone permission | Record without permission granted | Permission dialog shown, recording starts after grant | | | |
| 10.11 | Microphone permission denied | Deny microphone permission | Graceful error message, no crash | | | |
| 10.12 | Audio with video file URL | Audio message with .mov URL (data integrity) | Warning logged, no crash, graceful handling | | | |

---

## 11. Chat — Document Sharing

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 11.1 | Send document | Tap attachment → select PDF/document | Document uploads, file bubble shown with name/size | | | |
| 11.2 | View document | Tap document message | Document viewer opens (PDF viewer for PDFs) | | | |
| 11.3 | Download document | Tap download on document | File saved to device | | | |
| 11.4 | Document — file name display | View document bubble | Correct file name and file size shown | | | |
| 11.5 | Text file viewer | Open .txt file | Text content displayed in viewer | | | |
| 11.6 | Unsupported file type | Tap unsupported file | Fallback: opens external app or shows notice | | | |

---

## 12. Audio & Video Calling

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 12.1 | Initiate audio call | Tap audio call button from chat/expert | Outgoing call screen, ringtone plays | | | |
| 12.2 | Initiate video call | Tap video call button from chat/expert | Outgoing call with local video preview | | | |
| 12.3 | Receive incoming call — app foreground | Other user calls while app is open | Incoming call banner/dialog with accept/decline | | | |
| 12.4 | Receive incoming call — app background | Other user calls while app is backgrounded | Push notification / CallKit (iOS) | | | N/A |
| 12.5 | Accept incoming call | Tap Accept on incoming call | Call connects, audio/video streams start | | | |
| 12.6 | Decline incoming call | Tap Decline on incoming call | Call ended, caller notified | | | |
| 12.7 | Call connected — audio | Both parties on call | Two-way audio, duration timer starts | | | |
| 12.8 | Call connected — video | Both parties on video call | Local + remote video feeds visible | | | |
| 12.9 | Mute/unmute mic | Tap mute button during call | Mic toggles, other party can/cannot hear | | | |
| 12.10 | Toggle camera on/off | Tap camera toggle during video call | Camera on/off, other party sees/loses video | | | |
| 12.11 | Switch camera | Tap flip camera button | Front ↔ rear camera switch | | | N/A |
| 12.12 | Toggle speaker | Tap speaker button during call | Audio switches between speaker/earpiece | | | N/A |
| 12.13 | End call — initiator | Tap end call button | Call ends for both parties, summary shown | | | |
| 12.14 | End call — other party | Other party hangs up | Call ends, "Call ended" shown | | | |
| 12.15 | Minimize call (PiP) | Tap minimize or navigate away during call | Floating mini call view visible | | | |
| 12.16 | Restore from PiP | Tap minimized call view | Full call screen restored | | | |
| 12.17 | Call log created | After call ends | Call entry appears in Call History tab | | | |
| 12.18 | Post-call rating prompt | End call lasting ≥ 30 seconds | Rating dialog appears | | | |
| 12.19 | Network quality indicator | Make call on varying networks | Network quality icon updates | | | |
| 12.20 | Call timeout — no answer | Call rings for 30s+ with no answer | Call auto-ends, "No answer" status | | | |
| 12.21 | Call reconnection | Brief network drop during call | Call attempts reconnection, indicator shown | | | |
| 12.22 | Concurrent call prevention | Try calling while already on a call | Blocked with appropriate message | | | |
| 12.23 | CallKit integration (iOS) | Receive call on iOS | Native iOS call UI shown | | N/A | N/A |

---

## 13. Call History

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 13.1 | Call history loads | Navigate to Calls tab | List of past calls with details | | | |
| 13.2 | Call history — details | View call entry | Shows caller name, type (audio/video), duration, timestamp | | | |
| 13.3 | Call history — missed call | Miss an incoming call | Entry shows "Missed" in red | | | |
| 13.4 | Call from history | Tap a call history entry | Initiates new call to that user | | | |
| 13.5 | Call history — empty state | New user with no calls | Empty state message shown | | | |
| 13.6 | Call history — pagination | User with many calls | Older entries load on scroll | | | |

---

## 14. User Profile & Settings

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 14.1 | View own profile | Navigate to Profile tab | Shows name, photo, bio, skills, languages | | | |
| 14.2 | Edit name | Tap Edit → change name → Save | Name updated across app | | | |
| 14.3 | Edit bio | Tap Edit → change bio → Save | Bio text updated | | | |
| 14.4 | Change profile picture — gallery | Edit → tap photo → select from gallery | Photo updated, cached version refreshes | | | |
| 14.5 | Change profile picture — camera | Edit → tap photo → take new photo | Photo captured and uploaded | | | N/A |
| 14.6 | Remove profile picture | Edit → tap photo → remove | Default avatar shown | | | |
| 14.7 | Update skills | Profile → Edit Skills → toggle skills | Skills updated and saved | | | |
| 14.8 | Update languages | Profile → Edit Languages → select | Languages updated | | | |
| 14.9 | Toggle biometric lock | Settings → toggle biometric | Setting saved, takes effect on next launch | | | N/A |
| 14.10 | View storage usage | Profile → Storage section | Shows total app storage size (matches Settings) | | | |
| 14.11 | Clear cache | Profile → Storage → Clear Cache | Cache cleared, size drops to near 0 | | | |
| 14.12 | Logout | Profile → Logout → Confirm | Session cleared, navigated to login screen | | | |
| 14.13 | Delete account | Profile → Delete Account → Confirm | Account deleted, all data removed, navigated to login | | | |
| 14.14 | Profile picture appears everywhere | Change photo, check chat list, expert card, call screen | Updated photo shown in all locations | | | |

---

## 15. Photo Backup

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 15.1 | Enable photo backup | Profile → Photo Backup → Enable | Backup service starts | | | N/A |
| 15.2 | Photos upload | Enable backup with photos on device | Photos upload to cloud storage | | | N/A |
| 15.3 | Backup progress | View backup screen during upload | Progress indicator shown | | | N/A |
| 15.4 | Disable photo backup | Toggle backup off | Backup stops, existing backups remain | | | N/A |
| 15.5 | Gallery permission | Enable backup without gallery permission | Permission dialog shown | | | N/A |
| 15.6 | Gallery permission denied | Deny gallery permission | Graceful message, no crash | | | N/A |

---

## 16. Ratings & Reviews

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 16.1 | Post-call rating dialog | End call ≥ 30s | Star rating dialog appears | | | |
| 16.2 | Submit rating (1-5 stars) | Select star count → tap submit | Rating saved, dialog closes | | | |
| 16.3 | Add review text | Select stars → type review → submit | Rating with text saved | | | |
| 16.4 | Anonymous review toggle | Toggle "anonymous" on before submit | Review shows as anonymous | | | |
| 16.5 | Skip rating | Dismiss rating dialog | No rating saved, dialog closes | | | |
| 16.6 | View expert ratings | Expert profile → Reviews section | List of reviews with stars and text | | | |
| 16.7 | Reviews pagination | Expert with many reviews | Older reviews load on scroll | | | |
| 16.8 | Average rating display | View expert card/profile | Average star rating calculated correctly | | | |

---

## 17. Support & Help Center

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 17.1 | Open help center | Profile → Help / Support | Help center screen with FAQs and ticket option | | | |
| 17.2 | Browse FAQ categories | Tap FAQ categories | Category list with expandable items | | | |
| 17.3 | Expand FAQ | Tap on a FAQ item | Answer expands below question | | | |
| 17.4 | Mark FAQ helpful | Tap "Helpful" on FAQ | Counter increments, feedback recorded | | | |
| 17.5 | Create support ticket | Tap "Contact Support" → fill form | Ticket created, conversation opens | | | |
| 17.6 | Ticket — select category | Choose category (bug/feature/question) | Category saved on ticket | | | |
| 17.7 | Ticket — attach images | Add up to 5 image attachments | Images upload and display in ticket | | | |
| 17.8 | Ticket — exceed attachment limit | Try to add 6th attachment | Error: max 5 attachments | | | |
| 17.9 | Send ticket message | Type in ticket conversation → send | Message appears in thread | | | |
| 17.10 | Receive support reply | Support agent replies | Reply appears in real-time | | | |
| 17.11 | Ticket satisfaction rating | Ticket resolved → rate dialog | 1-5 star rating with comment | | | |
| 17.12 | View ticket list | Open support → My Tickets | List of all tickets with status | | | |
| 17.13 | Ticket status indicators | View tickets | Open/In Progress/Resolved badges correct | | | |
| 17.14 | Submit feedback | Tap "Send Feedback" option | Feedback form opens and submits | | | |

---

## 18. Admin Panel

> **Prerequisite**: Test with accounts that have admin/super-admin roles.

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 18.1 | Admin access — authorized | Login with admin account | Admin tab/panel visible | | | |
| 18.2 | Admin access — unauthorized | Login with regular account | Admin panel hidden / no access | | | |
| 18.3 | Admin — ticket list | Open Admin → Tickets tab | All support tickets listed | | | |
| 18.4 | Admin — ticket detail | Tap a ticket | Full ticket conversation with actions | | | |
| 18.5 | Admin — assign ticket | Assign ticket to self | Assignment saved, status updates | | | |
| 18.6 | Admin — add internal note | Add internal note to ticket | Note saved, visible to admins only | | | |
| 18.7 | Admin — change ticket status | Change status (Open → In Progress → Resolved) | Status updates, user notified | | | |
| 18.8 | Admin — user list | Open Admin → Users tab | All users listed with roles | | | |
| 18.9 | Admin — user detail | Tap a user | User details sheet with profile info | | | |
| 18.10 | Admin — edit user roles | Tap Edit Roles on user | Role checkboxes, save updates roles | | | |
| 18.11 | Admin — suspend user | Tap Suspend on user | User account suspended, badge shown | | | |
| 18.12 | Admin — unsuspend user | Tap Unsuspend on suspended user | Suspension lifted | | | |
| 18.13 | Admin — manage skills | Open Admin → Skills tab | CRUD operations for skill categories | | | |
| 18.14 | Admin — manage FAQs | Open Admin → FAQs tab | CRUD operations for FAQ items | | | |
| 18.15 | Admin — role hierarchy | Support agent attempts super-admin actions | Actions blocked based on role level | | | |
| 18.16 | Admin — user profile pics cached | Scroll admin user list | Profile pictures load from cache, no flicker on scroll | | | |

---

## 19. Push Notifications

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 19.1 | Notification permission prompt | First launch on iOS / Android 13+ | Permission dialog shown | | | |
| 19.2 | Chat message notification | Receive message while app backgrounded | Notification with sender name and message preview | | | |
| 19.3 | Notification tap — open chat | Tap chat notification | App opens directly to that conversation | | | |
| 19.4 | Call notification | Receive call while app backgrounded | Call notification / CallKit (iOS) | | | N/A |
| 19.5 | Notification tap — incoming call | Tap call notification | Call screen opens with accept/decline | | | N/A |
| 19.6 | Foreground notification suppression | Receive message while viewing same chat | No notification shown (already in chat) | | | |
| 19.7 | Support ticket notification | Support agent replies to ticket | Notification received with ticket reference | | | |
| 19.8 | Badge count | Receive multiple unread notifications | Badge count on app icon updates | | | N/A |
| 19.9 | Notification — app killed | Receive notification with app killed | Notification shows, tap opens app to correct screen | | | |
| 19.10 | Notification channels (Android) | Check Android notification settings | Separate channels for chat, calls, support | N/A | | N/A |

---

## 20. Presence & Online Status

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 20.1 | Online status — visible | Open app, check from another account | User shows as online (green dot) | | | |
| 20.2 | Offline status — visible | Close app, check from another account | User shows as offline after timeout | | | |
| 20.3 | Last seen timestamp | View offline user's profile | "Last seen" time displayed | | | |
| 20.4 | Presence in chat list | View chat list | Online contacts show green indicator | | | |
| 20.5 | Presence in chat header | Open conversation with online user | Online status shown in chat bar | | | |
| 20.6 | Background disconnect | Put app in background for extended time | Status transitions to offline | | | |

---

## 21. Caching & Storage

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 21.1 | Image cache — first load | View chat with images for first time | Images download and cache (visible in storage) | | | |
| 21.2 | Image cache — subsequent load | Close and reopen same chat | Images load instantly from disk cache | | | |
| 21.3 | Video cache — first load | Play video message first time | Video downloads and caches | | | |
| 21.4 | Video cache — subsequent load | Play same video again | Video plays instantly from cache | | | |
| 21.5 | Audio cache — first playback | Play audio message first time | Audio may stream, then caches | | | |
| 21.6 | Audio cache — subsequent play | Play same audio again | Plays instantly from local cache (no delay) | | | N/A |
| 21.7 | Profile picture cache | View profile pic, go offline, view again | Cached image displays | | | |
| 21.8 | Storage size — accurate | Profile → Storage | Size roughly matches iPhone/Android Settings app | | | N/A |
| 21.9 | Clear cache — frees space | Clear cache, check size | Size drops significantly | | | |
| 21.10 | Cache eviction (LRU) | Fill cache beyond limit | Oldest cached files evicted | | | |
| 21.11 | Media prefetch | Open a chat room | Recent audio/video/image files prefetch in background | | | |

---

## 22. Offline & Error Handling

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 22.1 | Offline — chat list | Go offline, open chat list | Cached conversations shown | | | |
| 22.2 | Offline — send message | Go offline, send text message | Message queued or error shown | | | |
| 22.3 | Offline — view cached media | Go offline, open chat with cached images | Cached images display, uncached show placeholder | | | |
| 22.4 | Network recovery | Go offline → send message → reconnect | Queued message sends on reconnection | | | |
| 22.5 | Server error | Simulate 500 error (if possible) | Error message shown, no crash | | | |
| 22.6 | Firebase Auth token expiry | Leave app overnight, reopen | Token refreshes silently, no re-login needed | | | |
| 22.7 | Circuit breaker — calling | Multiple call failures | Circuit breaker activates, prevents storm of retries | | | |
| 22.8 | Crashlytics reporting | Trigger an error | Error logged in Firebase Crashlytics dashboard | | | |
| 22.9 | Graceful degradation | Firestore temporarily unavailable | App shows cached data, error banner, no crash | | | |

---

## 23. Performance & Memory

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 23.1 | App startup time | Cold start from killed state | App interactive within 3 seconds | | | |
| 23.2 | Chat scroll performance | Open chat with 200+ messages, scroll rapidly | Smooth 60fps scrolling, no jank | | | |
| 23.3 | Image list performance | Chat with many images, scroll | No memory spikes, images load/unload efficiently | | | |
| 23.4 | Long call stability | Stay on 10+ minute call | No audio/video degradation over time | | | |
| 23.5 | Background memory | Background app for 30 minutes | App not killed by OS, reasonable memory use | | | N/A |
| 23.6 | Multiple audio messages | Chat with 10+ audio messages visible | No duplicate audio playback, only one plays at a time | | | |
| 23.7 | Stream/listener cleanup | Navigate back and forth between screens | No duplicate listeners, memory stable | | | |

---

## 24. Platform-Specific Behavior

### iOS Specific

| # | Test Case | Steps | Expected Result |
|---|-----------|-------|-----------------|
| 24.1 | CallKit incoming call | Receive call with app backgrounded | Native iOS call screen shown |
| 24.2 | CallKit — answer from lock screen | Receive call on locked device | Slide to answer works |
| 24.3 | Face ID prompt | Open app with biometric enabled | Face ID dialog, natural-feeling |
| 24.4 | iOS permissions — camera | First camera use | iOS permission dialog |
| 24.5 | iOS permissions — microphone | First recording/call | iOS permission dialog |
| 24.6 | iOS audio session — calling | On call, receive text notification | Notification doesn't interrupt call audio |
| 24.7 | iOS audio session — playback | Play audio message | Audio routes to speaker, not earpiece |
| 24.8 | VoIP push notification | Receive call with app killed | VoIP push triggers CallKit |

### Android Specific

| # | Test Case | Steps | Expected Result |
|---|-----------|-------|-----------------|
| 24.9 | OTP auto-verification | Receive SMS OTP on Android | OTP detected and auto-filled |
| 24.10 | Notification channels | Check Android notification settings | Separate channels configured |
| 24.11 | Fingerprint prompt | Open app with biometric enabled | Fingerprint dialog |
| 24.12 | Background restrictions | Battery optimization on | App still receives notifications |
| 24.13 | Android back button | Press back on various screens | Correct back-navigation behavior |

### Web Specific

| # | Test Case | Steps | Expected Result |
|---|-----------|-------|-----------------|
| 24.14 | Web — no biometric | Check settings on web | Biometric option hidden |
| 24.15 | Web — no camera capture | Attachment picker on web | Camera option hidden or adapted |
| 24.16 | Web — audio playback | Play audio message on web | Uses network URL, no DeviceFileSource errors |
| 24.17 | Web — PDF viewer | Open PDF document on web | Web-compatible PDF viewer used |
| 24.18 | Web — responsive layout | Resize browser window | Layout adapts gracefully |

---

## 25. Accessibility & Edge Cases

| # | Test Case | Steps | Expected Result | iOS | Android | Web |
|---|-----------|-------|-----------------|-----|---------|-----|
| 25.1 | Dark mode | System dark mode on | All screens readable, proper contrast | | | |
| 25.2 | Large text / Dynamic Type | Set accessibility large text | Text scales, no overflow/clipping | | | |
| 25.3 | Screen reader | Enable VoiceOver (iOS) / TalkBack (Android) | Key elements have semantic labels | | | N/A |
| 25.4 | Orientation change | Rotate device during chat | Layout adjusts without crash | | | N/A |
| 25.5 | Low storage | Device with very low storage | Graceful error when download/upload fails | | | N/A |
| 25.6 | Interrupted upload | Kill app during media upload | No corrupt data, upload can be retried | | | |
| 25.7 | Rapid navigation | Quickly tap back/forward through screens | No double-navigation or crashes | | | |
| 25.8 | Concurrent sessions | Same account logged in on two devices | State syncs, no conflicts | | | |
| 25.9 | Long user name | User with very long name | Name truncates with ellipsis, no overflow | | | |
| 25.10 | Special characters | Send emoji, RTL text, special chars | Renders correctly, no encoding issues | | | |
| 25.11 | Shake to toggle debug logs | Shake device with app open | Verbose logging toggle snackbar appears | | | N/A |
| 25.12 | Account suspended | Login with suspended account | Appropriate blocked/suspended message | | | |

---

## Test Environment Checklist

Before testing, ensure:

- [ ] **iOS Device**: iPhone running iOS 16+ (physical device preferred for calls/camera)
- [ ] **Android Device**: Android 10+ (physical device preferred)
- [ ] **Web Browser**: Chrome/Safari latest
- [ ] **Test Accounts**: At minimum 2 user accounts, 1 expert account, 1 admin account
- [ ] **Network Conditions**: Test on both WiFi and cellular
- [ ] **Firebase Backend**: Production environment or staging mirror
- [ ] **Push Notification Setup**: APNs configured (iOS), FCM configured (Android)

---

## Sign-Off

| Role | Name | Date | Status |
|------|------|------|--------|
| QA Lead | | | |
| Developer | | | |
| Product Owner | | | |

---

*Total test cases: ~200+ across 25 sections*
