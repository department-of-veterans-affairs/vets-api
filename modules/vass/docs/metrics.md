# VASS Module - Metrics Tracking Documentation

## Overview

The VASS (Virtual Agent Scheduling System) module implements comprehensive metrics tracking using Datadog's StatsD client for performance monitoring, error analysis, and operational visibility.

**Total Metrics**: 24 (14 controller + 10 infrastructure)

---

## Table of Contents

1. [Naming Convention](#naming-convention)
2. [Complete Metric List](#complete-metric-list)
3. [Tagging Strategy](#tagging-strategy)
4. [Monitoring & Alerts](#monitoring--alerts)

---

## Naming Convention

All VASS metrics follow this pattern:

```
api.vass.{layer}.{component}.{action}.{outcome}
```

**Layers**:

- `controller` - User-facing API endpoints (success/failure)
- `infrastructure` - Rate limiting, session lifecycle, auth failures, availability scenarios

---

## Complete Metric List

### Controller Metrics (14 metrics: 7 endpoints × 2 outcomes)

| Endpoint                        | Success Metric                      | Failure Metric                      | Purpose                       |
| ------------------------------- | ----------------------------------- | ----------------------------------- | ----------------------------- |
| `POST /request-otp`             | `sessions.request_otp.success`      | `sessions.request_otp.failure`      | OTP generation & delivery     |
| `POST /authenticate-otp`        | `sessions.authenticate_otp.success` | `sessions.authenticate_otp.failure` | OTP validation & JWT creation |
| `POST /revoke-token`            | `sessions.revoke_token.success`     | `sessions.revoke_token.failure`     | JWT token revocation          |
| `GET /appointment-availability` | `appointments.availability.success` | `appointments.availability.failure` | Availability checks           |
| `GET /topics`                   | `appointments.topics.success`       | `appointments.topics.failure`       | Agent skills retrieval        |
| `POST /appointment`             | `appointments.create.success`       | `appointments.create.failure`       | Appointment creation          |
| `GET /appointment/:id`          | `appointments.show.success`         | `appointments.show.failure`         | Appointment retrieval         |
| `POST /appointment/:id/cancel`  | `appointments.cancel.success`       | `appointments.cancel.failure`       | Appointment cancellation      |

**Common Tags**: `service:vass`, `endpoint:{action}`, `http_method:{GET|POST}`, `http_status:{code}`, `error_type:{ErrorClass}` (failures only)

### Infrastructure Metrics (10 metrics)

**Rate Limiting** (2 metrics):

- `api.vass.infrastructure.rate_limit.generation.exceeded` - OTP generation violations
- `api.vass.infrastructure.rate_limit.validation.exceeded` - OTP validation violations

**Session Lifecycle** (3 metrics):

- `api.vass.infrastructure.session.otp.expired` - Expired OTP attempts
- `api.vass.infrastructure.session.otp.invalid` - Invalid OTP attempts
- `api.vass.infrastructure.session.jwt.expired` - JWT session timeout

**Auth Failures** (1 metric):

- `api.vass.infrastructure.auth.identity_validation.failure` - Identity verification failures (last name/DOB mismatch)

**Availability Scenarios** (4 metrics):

- `api.vass.infrastructure.availability.no_slots_available` - **CRITICAL**: In valid window, zero slots
- `api.vass.infrastructure.availability.already_booked` - Veteran checking after booking
- `api.vass.infrastructure.availability.next_cohort` - Booking window not open yet
- `api.vass.infrastructure.availability.no_cohorts` - Outside all cohort windows

**Tags**: `service:vass` (all infrastructure metrics)

---

## Tagging Strategy

### Standard Tags (All Metrics)

- `service:vass` - Always present on all metrics

### Controller Tags

- `endpoint:{action}` - Action name (e.g., `create`, `availability`)
- `http_method:{GET|POST}` - HTTP verb
- `http_status:{code}` - Response status code
- `error_type:{ErrorClass}` - Error class name (failures only)

### Auth Failure Tags

Auth failure metrics include an `attempt` tag to track retry patterns:

- `attempt:{N}` - Current attempt number (bounded by rate limit max attempts, typically 3-5)

This applies to:
- `api.vass.infrastructure.auth.identity_validation.failure`
- `api.vass.infrastructure.session.otp.invalid`

---

## Monitoring & Alerts

### Critical Alerts

| Metric | Threshold | Action |
| ------ | --------- | ------ |
| `api.vass.controller.*.failure` | > 10% of requests in 5 minutes | Page on-call engineer |
| `api.vass.infrastructure.rate_limit.*.exceeded` | > 50 events in 5 minutes | Page security team |
| `api.vass.infrastructure.availability.no_slots_available` | > 10 events in 15 minutes | Page on-call + capacity team |
| `api.vass.infrastructure.session.jwt.expired` | > 20 events in 10 minutes | Notify team slack |

### Warning Alerts

| Metric | Threshold | Action |
| ------ | --------- | ------ |
| `api.vass.controller.*.failure` | > 5% of requests in 10 minutes | Notify team slack |
| `api.vass.infrastructure.availability.already_booked` | > 30% of availability checks in 1 hour | Notify UX team |
| `api.vass.infrastructure.auth.identity_validation.failure` | > 20 events in 10 minutes | Notify team slack |

### Key Dashboards

[**VASS Overview**](https://vagov.ddog-gov.com/dashboard/fw6-j3c-zns):

- Success rate (all endpoints)
- Error breakdown by error_type
- Availability scenarios breakdown

**Authentication Flow**:

- OTP generation → validation → JWT creation funnel
- Rate limit violations
- Invalid/expired OTP attempts
- Identity validation failures by attempt number
- Session timeouts

**Availability Insights**:

- `no_slots_available` ratio to total checks (capacity indicator)
- `already_booked` trend (UX/communication issue)
- `next_cohort` / `no_cohorts` (engagement patterns)

### SLOs

- **Availability**: 99.5% success rate across all endpoints
- **Authentication**: 98% OTP validation success rate

### Datadog Watchdog

Datadog's AI-powered Watchdog automatically monitors all `api.vass.*` metrics for anomalies. It detects unusual error rate spikes, traffic pattern changes, and deployment regressions.

**Access**: `https://app.datadoghq.com/watchdog?service=vass`
