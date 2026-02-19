# Firebase Console Setup Guide

This guide provides step-by-step instructions for configuring Firebase Console to complete the observability setup for GreenHive app.

## Table of Contents

1. [Crashlytics Alerts](#1-crashlytics-alerts)
2. [Performance Monitoring Alerts](#2-performance-monitoring-alerts)
3. [BigQuery Export](#3-bigquery-export)
4. [Custom Dashboards](#4-custom-dashboards)
5. [Analytics Audiences](#5-analytics-audiences)

---

## 1. Crashlytics Alerts

### 1.1 Configure Velocity Alerts

Velocity alerts notify you when crash rates spike above normal levels.

**Steps:**

1. Go to [Firebase Console](https://console.firebase.google.com) → Select your project
2. Navigate to **Crashlytics** in the left sidebar
3. Click the **gear icon** (⚙️) in the top right → **Alerting preferences**
4. Enable the following alerts:

| Alert Type | Recommended Threshold | Description |
|------------|----------------------|-------------|
| **New fatal issue** | Always | First occurrence of a new crash |
| **Regressed issue** | Always | Previously closed crash reappears |
| **Velocity alert** | 0.1% of sessions | Sudden spike in crash rate |
| **Trending issue** | Top 5 | Crashes affecting many users |

### 1.2 Set Up Notification Channels

1. In **Alerting preferences**, click **Manage notification channels**
2. Add channels:
   - **Email**: Add team email addresses
   - **Slack**: Install Firebase integration ([instructions](https://firebase.google.com/docs/crashlytics/get-deobfuscated-reports?platform=flutter#slack))
   - **PagerDuty**: For on-call rotation (optional)

### 1.3 Configure Issue Severity

1. Go to **Crashlytics** → **Issues** tab
2. For each important crash, click to open details
3. Set **Priority** (P1-P4) based on impact
4. Add **Notes** for context

---

## 2. Performance Monitoring Alerts

### 2.1 Custom Trace Alerts

Set alerts for the performance traces we implemented.

**Steps:**

1. Go to **Performance** in Firebase Console
2. Click **Dashboard** → **Custom traces** tab
3. For each trace, click the **3-dot menu** → **Set up alert**

**Recommended Alert Thresholds:**

| Trace Name | Metric | Condition | Threshold |
|------------|--------|-----------|-----------|
| `call_setup_outgoing` | Duration | > | 5000ms |
| `call_setup_incoming` | Duration | > | 3000ms |
| `message_send` | Duration | > | 2000ms |
| `media_upload` | Duration | > | 30000ms |

### 2.2 Network Request Alerts

1. Go to **Performance** → **Network requests** tab
2. Click on important endpoints (e.g., Cloud Functions)
3. Set alerts for:
   - Response time > 5s
   - Error rate > 5%

### 2.3 Screen Rendering Alerts

1. Go to **Performance** → **Screen rendering** tab
2. Set alerts for:
   - Slow frames > 20%
   - Frozen frames > 5%

---

## 3. BigQuery Export

BigQuery export enables advanced analytics, long-term data retention, and custom SQL queries.

### 3.1 Enable Crashlytics Export

1. Go to **Project Settings** (gear icon) → **Integrations** tab
2. Find **BigQuery** section → Click **Link**
3. Select a BigQuery location (choose same region as your Firebase project)
4. Enable **Crashlytics** streaming export
5. Click **Link to BigQuery**

**Data Available:**
- Crash events with full stack traces
- Device information
- Custom keys and logs
- User identifiers (hashed)

### 3.2 Enable Analytics Export

1. In the same **Integrations** → **BigQuery** section
2. Enable **Google Analytics** export
3. Choose export frequency:
   - **Streaming** (real-time, higher cost)
   - **Daily** (recommended for most cases)

**Data Available:**
- All analytics events with parameters
- User properties
- Session data
- Conversion funnels

### 3.3 BigQuery Tables Created

After enabling, these tables will be created in your BigQuery dataset:

```
project_id.analytics_XXXXX.events_*        # Analytics events (daily tables)
project_id.analytics_XXXXX.events_intraday_* # Streaming events
project_id.firebase_crashlytics.project_name_PLATFORM # Crashlytics data
```

### 3.4 Sample Queries

**Daily Active Users:**
```sql
SELECT
  COUNT(DISTINCT user_pseudo_id) as daily_active_users,
  PARSE_DATE('%Y%m%d', event_date) as date
FROM `project_id.analytics_XXXXX.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20260101' AND '20260131'
GROUP BY date
ORDER BY date
```

**Call Success Rate:**
```sql
SELECT
  PARSE_DATE('%Y%m%d', event_date) as date,
  COUNTIF(event_name = 'call_callConnected') as successful_calls,
  COUNTIF(event_name = 'call_callFailed') as failed_calls,
  SAFE_DIVIDE(
    COUNTIF(event_name = 'call_callConnected'),
    COUNTIF(event_name IN ('call_callConnected', 'call_callFailed'))
  ) * 100 as success_rate_percent
FROM `project_id.analytics_XXXXX.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20260101' AND '20260131'
  AND event_name IN ('call_callConnected', 'call_callFailed')
GROUP BY date
ORDER BY date
```

**Auth Funnel Analysis:**
```sql
SELECT
  COUNTIF(event_name = 'auth_enter_phone') as phone_entered,
  COUNTIF(event_name = 'auth_request_otp') as otp_requested,
  COUNTIF(event_name = 'auth_verify_otp' 
    AND (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'success') = 'true') as otp_verified,
  COUNTIF(event_name = 'auth_login_complete') as login_complete
FROM `project_id.analytics_XXXXX.events_*`
WHERE _TABLE_SUFFIX = FORMAT_DATE('%Y%m%d', CURRENT_DATE())
```

---

## 4. Custom Dashboards

### 4.1 Firebase Console Dashboard (Built-in)

The Firebase Console provides pre-built dashboards. Customize the home dashboard:

1. Go to **Project Overview** (home)
2. Click **Customize dashboard**
3. Add cards for:
   - Active users (real-time)
   - Crash-free users percentage
   - Top crashes
   - Revenue (if applicable)

### 4.2 Looker Studio Dashboard (Recommended)

For advanced visualization, use Google Looker Studio (formerly Data Studio) with BigQuery.

**Setup Steps:**

1. Go to [Looker Studio](https://lookerstudio.google.com)
2. Click **Create** → **Report**
3. Add **BigQuery** as data source
4. Select your Firebase Analytics dataset

**Recommended Dashboard Pages:**

#### Page 1: Executive Summary
- Daily/Weekly/Monthly Active Users (line chart)
- Crash-free user rate (scorecard)
- Key feature adoption rates (bar chart)
- Revenue metrics (if applicable)

#### Page 2: Authentication Funnel
- Auth funnel visualization (funnel chart)
  - Phone entered → OTP requested → OTP verified → Login complete
- Drop-off rates at each step
- Conversion by country code

#### Page 3: Calling Performance
- Call success rate over time (line chart)
- Average call setup time (line chart)
- Call duration distribution (histogram)
- Failure reasons breakdown (pie chart)

#### Page 4: Chat Engagement
- Messages sent per day (line chart)
- Media types breakdown (pie chart)
- Active conversations (scorecard)
- Message delivery success rate

#### Page 5: Error Analysis
- Crash rate over time (line chart)
- Top 10 crashes (table)
- Crashes by device/OS (bar chart)
- Non-fatal error trends

### 4.3 Sample Looker Studio Template

Create calculated fields for common metrics:

```
// Crash-free rate
1 - (crash_events / total_sessions) * 100

// Call success rate
successful_calls / (successful_calls + failed_calls) * 100

// Auth conversion rate
login_complete / phone_entered * 100
```

---

## 5. Analytics Audiences

Audiences help segment users for analysis and targeting.

### 5.1 Create Key Audiences

1. Go to **Analytics** → **Audiences** tab
2. Click **New audience**

**Recommended Audiences:**

| Audience Name | Conditions | Purpose |
|---------------|------------|---------|
| **Expert Users** | user_type = 'expert' | Track expert engagement |
| **New Users (7 days)** | First open within 7 days | Onboarding optimization |
| **Power Users** | Sessions > 10 in 7 days | Identify engaged users |
| **Call Users** | call_callStarted event | Users who make calls |
| **Churning Users** | No session in 14 days | Re-engagement campaigns |
| **Premium Prospects** | High engagement + no purchase | Conversion targets |

### 5.2 Audience Triggers

Set up audience triggers to fire events when users enter/exit audiences:

1. When creating audience, enable **Audience trigger**
2. This creates an event like `audience_joined_power_users`
3. Use for personalization or notifications

---

## 6. Alerting Best Practices

### 6.1 Alert Fatigue Prevention

- Start with higher thresholds, tighten over time
- Use percentage-based alerts over absolute numbers
- Group related alerts into digests
- Set up escalation policies (alert → warning → critical)

### 6.2 On-Call Rotation

For production apps, set up on-call rotation:

1. Use PagerDuty or Opsgenie integration
2. Define escalation policies:
   - Level 1: Primary on-call (5 min response)
   - Level 2: Backup on-call (15 min)
   - Level 3: Engineering lead (30 min)

### 6.3 Incident Response Playbook

When an alert fires:

1. **Acknowledge** the alert within SLA
2. **Assess** severity using Crashlytics details
3. **Communicate** to stakeholders if P1/P2
4. **Investigate** using logs, traces, and analytics
5. **Remediate** with hotfix or rollback
6. **Document** in post-mortem

---

## 7. Maintenance Checklist

### Weekly
- [ ] Review top crashes in Crashlytics
- [ ] Check performance trace trends
- [ ] Verify alerting is working (test alert)

### Monthly
- [ ] Review and tune alert thresholds
- [ ] Analyze BigQuery data for trends
- [ ] Update dashboards with new metrics
- [ ] Clean up resolved issues in Crashlytics

### Quarterly
- [ ] Review data retention policies
- [ ] Audit BigQuery costs
- [ ] Update audiences based on product changes
- [ ] Review and update this documentation

---

## 8. Cost Considerations

### Firebase Costs
- **Crashlytics**: Free
- **Performance**: Free (with limits)
- **Analytics**: Free

### BigQuery Costs
- **Storage**: ~$0.02/GB/month
- **Queries**: ~$5/TB scanned
- **Streaming inserts**: ~$0.01/200MB

**Cost Optimization Tips:**
1. Use daily export instead of streaming for Analytics
2. Set up BigQuery table expiration (e.g., 90 days for raw events)
3. Create aggregated tables for common queries
4. Use partitioned tables to reduce query costs

---

## Quick Reference

| Task | Location |
|------|----------|
| View crashes | Firebase Console → Crashlytics |
| View performance | Firebase Console → Performance |
| View analytics | Firebase Console → Analytics |
| Configure alerts | Crashlytics/Performance → Settings → Alerts |
| BigQuery export | Project Settings → Integrations → BigQuery |
| Create audiences | Analytics → Audiences |
| Custom dashboards | Looker Studio → Create Report |

---

*Last updated: February 2026*
