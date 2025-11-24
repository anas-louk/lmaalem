# WebRTC TURN/STUN Server Configuration Guide

## Overview

This guide explains how to configure TURN/STUN servers for reliable WebRTC audio-only calls across different network conditions (Wi-Fi, 4G/5G, NAT/firewalls).

## Architecture

### STUN Servers (Session Traversal Utilities for NAT)

**Purpose:** Discover public IP address and port mapping behind NAT.

**Status:** ✅ Configured (free Google STUN servers)

**Servers:**
- `stun:stun.l.google.com:19302`
- `stun:stun1.l.google.com:19302`
- `stun:stun2.l.google.com:19302`

**When STUN is sufficient:**
- Same network (Wi-Fi to Wi-Fi)
- Simple NAT configurations
- Most home/office networks

### TURN Servers (Traversal Using Relays around NAT)

**Purpose:** Relay media traffic when direct peer-to-peer connection fails.

**Status:** ⚠️ Not configured (STUN only)

**When TURN is required:**
- Restrictive NAT/firewalls
- Corporate networks
- Some mobile carriers
- Symmetric NAT configurations

## Configuration

### Current Setup

**File:** `lib/config/webrtc_config.dart`

**STUN servers:** ✅ Configured (3 servers)

**TURN servers:** ❌ Not configured (empty list)

### Adding TURN Server Credentials

1. **Open:** `lib/config/webrtc_config.dart`

2. **Update `turnServers` list:**

```dart
static const List<Map<String, String>> turnServers = [
  {
    'urls': 'turn:turn.example.com:3478',
    'username': 'your-username',
    'credential': 'your-password',
  },
  // Add multiple TURN servers for redundancy
  {
    'urls': 'turn:turn-backup.example.com:3478',
    'username': 'your-username',
    'credential': 'your-password',
  },
];
```

3. **Save and rebuild the app**

## TURN Server Providers

### Option 1: Twilio (Recommended for Production)

**URL:** https://www.twilio.com/stun-turn

**Features:**
- Reliable, scalable
- Pay-as-you-go pricing
- Global infrastructure

**Setup:**
1. Sign up for Twilio account
2. Get TURN credentials from Twilio console
3. Add to `webrtc_config.dart`

### Option 2: Metered TURN (Free Tier Available)

**URL:** https://www.metered.ca/tools/openrelay/

**Features:**
- Free tier available
- Easy setup
- Good for testing

**Setup:**
1. Sign up for Metered account
2. Get TURN credentials
3. Add to `webrtc_config.dart`

### Option 3: Self-Hosted coturn

**URL:** https://github.com/coturn/coturn

**Features:**
- Full control
- No per-call costs
- Requires server management

**Setup:**
1. Deploy coturn on your server
2. Configure authentication
3. Add credentials to `webrtc_config.dart`

## Testing Network Conditions

### Test Scenario 1: Same Wi-Fi Network

**Setup:**
- Both devices on same Wi-Fi network

**Expected:**
- ✅ STUN sufficient
- ✅ Direct peer-to-peer connection
- ✅ Low latency

**Test:**
1. Place call between two devices on same Wi-Fi
2. Verify audio connects
3. Check logs: Should see "ICE connection established"

### Test Scenario 2: Different Networks (Wi-Fi to 4G/5G)

**Setup:**
- Device A on Wi-Fi
- Device B on mobile data (4G/5G)

**Expected:**
- ✅ STUN usually sufficient
- ✅ Direct connection if NAT allows
- ⚠️ May require TURN if NAT is restrictive

**Test:**
1. Place call between Wi-Fi and mobile data
2. Verify audio connects
3. Check logs for ICE connection state

### Test Scenario 3: Restrictive NAT/Firewall

**Setup:**
- Corporate network
- Symmetric NAT
- Firewall restrictions

**Expected:**
- ❌ STUN may fail
- ✅ TURN required for reliable connection

**Test:**
1. Place call from corporate network
2. If connection fails, check logs:
   - Look for "ICE connection failed"
   - Add TURN server and retry

## Debugging Connection Issues

### Check ICE Connection State

**Logs to watch:**
```
[CallController] ICE connection state: <state>
```

**States:**
- `RTCIceConnectionStateNew`: Initial state
- `RTCIceConnectionStateChecking`: Checking connectivity
- `RTCIceConnectionStateConnected`: ✅ Success (direct connection)
- `RTCIceConnectionStateCompleted`: ✅ Success (via TURN)
- `RTCIceConnectionStateFailed`: ❌ Failed (may need TURN)
- `RTCIceConnectionStateDisconnected`: Connection lost

### Check ICE Candidates

**Logs to watch:**
```
[CallController] ICE candidate gathered: <candidate>
[CallController] Local ICE candidate published
[CallController] Remote ICE candidate applied
```

**What to look for:**
- Multiple candidates gathered (host, srflx, relay)
- Candidates successfully exchanged via Firestore
- Remote candidates applied to peer connection

### Common Issues

#### Issue 1: "ICE connection failed"

**Symptoms:**
- Call connects but audio doesn't work
- Logs show `RTCIceConnectionStateFailed`

**Solutions:**
1. Add TURN server configuration
2. Check network firewall settings
3. Verify STUN servers are accessible

#### Issue 2: "No ICE candidates gathered"

**Symptoms:**
- No candidates in logs
- Connection never establishes

**Solutions:**
1. Check microphone permissions
2. Verify network connectivity
3. Check if STUN servers are blocked

#### Issue 3: "ICE candidates not exchanged"

**Symptoms:**
- Local candidates gathered but remote not received

**Solutions:**
1. Check Firestore security rules
2. Verify `calls/{callId}/candidates` subcollection permissions
3. Check network connectivity to Firestore

## Fallback Logic

The current implementation uses a fallback strategy:

1. **Try STUN first:** Fastest, lowest latency
2. **Try TURN if STUN fails:** Automatic fallback if TURN configured
3. **Log failures:** For debugging and monitoring

**Note:** WebRTC automatically tries all configured ICE servers in order.

## Production Recommendations

### Minimum Configuration

- ✅ 3 STUN servers (already configured)
- ⚠️ At least 1 TURN server (recommended)

### Optimal Configuration

- ✅ 3 STUN servers (redundancy)
- ✅ 2+ TURN servers (redundancy, different providers)
- ✅ TURN servers in different regions (low latency)

### Monitoring

**Metrics to track:**
- ICE connection success rate
- STUN vs TURN usage
- Connection latency
- Failed connection attempts

**Logs to monitor:**
- `[CallController] ICE connection state`
- `[CallController] Connection state`
- `[WebRTCService] Peer connection created`

## Security Considerations

### TURN Server Credentials

- ⚠️ **Never commit credentials to version control**
- ✅ Use environment variables or secure config
- ✅ Rotate credentials regularly
- ✅ Use time-limited credentials (TURN REST API)

### Firestore Security Rules

Ensure `calls/{callId}/candidates` subcollection is properly secured:

```javascript
match /calls/{callId}/candidates/{candidateId} {
  allow read: if request.auth != null && (
    request.auth.uid == get(/databases/$(database)/documents/calls/$(callId)).data.callerId ||
    request.auth.uid == get(/databases/$(database)/documents/calls/$(callId)).data.calleeId
  );
  allow write: if request.auth != null && (
    request.auth.uid == request.resource.data.senderId ||
    request.auth.uid == get(/databases/$(database)/documents/calls/$(callId)).data.callerId ||
    request.auth.uid == get(/databases/$(database)/documents/calls/$(callId)).data.calleeId
  );
}
```

## Testing Checklist

- [ ] Test call on same Wi-Fi network
- [ ] Test call between Wi-Fi and mobile data
- [ ] Test call from corporate network (if applicable)
- [ ] Verify ICE candidates are gathered
- [ ] Verify ICE candidates are exchanged via Firestore
- [ ] Verify connection establishes successfully
- [ ] Test with TURN server configured (if available)
- [ ] Monitor logs for connection failures
- [ ] Test audio quality and latency

## Summary

**Current Status:**
- ✅ STUN servers configured (3 servers)
- ❌ TURN servers not configured
- ✅ ICE candidate exchange working
- ✅ Connection state monitoring enabled
- ✅ Comprehensive logging for debugging

**Next Steps:**
1. Test calls on various networks
2. If failures occur, add TURN server configuration
3. Monitor connection success rates
4. Optimize based on real-world usage

