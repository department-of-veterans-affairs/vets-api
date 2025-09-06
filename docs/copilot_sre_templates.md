# GitHub Copilot SRE Ticket Templates

## Overview
This document provides standardized prompts and templates for GitHub Copilot to generate SRE team tickets in the vets-api repository format.

## Base Prompt Template

Use this base prompt with Copilot to generate tickets:

```
Generate a GitHub issue for the vets-api SRE team using the following template:

Title: [ISSUE_TYPE] - [SERVICE] - [BRIEF_DESCRIPTION]

## Issue Type
[Bug | Incident | Enhancement | Maintenance | Security]

## Service/Component
[vets-api | database | redis | sidekiq | external-service]

## Priority
[Critical | High | Medium | Low]

## Description
[Detailed description of the issue]

## Current Behavior
[What is currently happening]

## Expected Behavior
[What should be happening]

## Impact Assessment
[Who/what is affected and how]

## Steps to Reproduce
[If applicable]

## Metrics/Evidence
[Links to dashboards, logs, monitoring data]

## Proposed Solution
[If known]

## Acceptance Criteria
[Checklist of items that must be completed]

## Labels
[Add appropriate labels: bug, enhancement, ops, security, etc.]
```

## Specific Template Examples

### 1. Production Bug Template

**Copilot Prompt:**
```
Generate a production bug ticket for vets-api with these details:
- Service: vets-api
- Issue: 500 errors increasing in mobile appointments endpoint
- Priority: High
- Affected: Mobile app users
- Evidence: DataDog dashboard showing error spike
```

**Expected Output:**
```markdown
## Issue Type
Bug

## Service/Component
vets-api - Mobile API (modules/mobile)

## Priority
High

## Description
Production 500 errors increasing on mobile appointments endpoint (/mobile/v0/appointments). Error rate has increased from baseline 0.1% to 3.2% over the past 2 hours.

## Current Behavior
- Mobile appointments endpoint returning HTTP 500 errors
- Error rate: 3.2% (up from 0.1% baseline)
- Affecting appointment retrieval for mobile users
- Backend service calls timing out

## Expected Behavior
- Appointments endpoint should return successful responses
- Error rate should remain below 0.5%
- Response time should be under 2 seconds

## Impact Assessment
- **Users Affected**: Mobile app users trying to view appointments
- **Business Impact**: Veterans cannot access appointment information
- **Estimated Affected Users**: ~1,200 users per hour
- **Severity**: Service degradation affecting core functionality

## Steps to Reproduce
1. Make GET request to `/mobile/v0/appointments`
2. With valid authenticated user
3. Observe intermittent 500 responses

## Metrics/Evidence
- DataDog Dashboard: [vets-api Mobile Endpoints](https://link-to-dashboard)
- Error logs: Check CloudWatch for stack traces
- Response time metrics showing degradation
- Time range: Past 2-4 hours

## Proposed Solution
1. Investigate recent deployments (past 4 hours)
2. Check external service dependencies (VEText, VAOS)
3. Review error logs for root cause
4. Consider circuit breaker activation if upstream issue

## Acceptance Criteria
- [ ] Root cause identified and documented
- [ ] Error rate returns to baseline (<0.5%)
- [ ] Response times return to normal (<2s)
- [ ] Monitoring alerts configured to prevent recurrence
- [ ] Post-incident review completed if warranted

## Labels
`bug`, `production`, `mobile`, `high-priority`, `api-endpoints`
```

### 2. Performance Issue Template

**Copilot Prompt:**
```
Generate a performance issue ticket for:
- Service: vets-api database
- Issue: Slow query performance on claims table
- Priority: Medium
- Impact: API response times increased
```

**Expected Output:**
```markdown
## Issue Type
Performance

## Service/Component
vets-api - PostgreSQL Database

## Priority
Medium

## Description
Slow query performance detected on claims table queries causing increased API response times. Several queries taking >5 seconds when normal response time is <500ms.

## Current Behavior
- Claims-related API endpoints responding slowly
- Database queries taking 5-15 seconds
- Connection pool exhaustion during peak hours
- Slow query logs showing expensive operations

## Expected Behavior
- Claims queries should complete in <500ms
- API response times should remain under 2 seconds
- Database connection pool should remain healthy

## Impact Assessment
- **Affected Services**: Claims API, Appeals API
- **User Experience**: Slow page loads, timeouts
- **Peak Hour Impact**: More severe during business hours (9 AM - 5 PM ET)
- **SLA Impact**: Response times exceeding 5-second threshold

## Metrics/Evidence
- DataDog Database Dashboard: [PostgreSQL Performance](https://link)
- Slow query log analysis needed
- APM traces showing database bottlenecks
- Connection pool metrics showing saturation

## Proposed Solution
1. Analyze slow query logs from past 24 hours
2. Identify missing indexes or inefficient queries
3. Review recent schema changes or migrations
4. Consider query optimization or index additions
5. Evaluate connection pool configuration

## Acceptance Criteria
- [ ] Slow queries identified and optimized
- [ ] Missing indexes added if appropriate
- [ ] Query performance returns to <500ms average
- [ ] Connection pool metrics healthy
- [ ] Documentation updated with findings

## Labels
`performance`, `database`, `optimization`, `medium-priority`
```

### 3. Security Incident Template

**Copilot Prompt:**
```
Generate a security incident ticket for:
- Service: vets-api
- Issue: Suspicious authentication attempts detected
- Priority: Critical
- Security concern: Potential brute force attack
```

**Expected Output:**
```markdown
## Issue Type
Security Incident

## Service/Component
vets-api - Authentication System

## Priority
Critical

## Description
🚨 SECURITY ALERT: Suspicious authentication attempts detected suggesting potential brute force attack against user accounts. Multiple failed login attempts from various IP addresses targeting specific user accounts.

## Current Behavior
- Increased failed authentication attempts (10x normal rate)
- Multiple IP addresses targeting same user accounts
- Authentication failure rate: 45% (normal: 5%)
- Potential credential stuffing or brute force pattern

## Expected Behavior
- Authentication failure rate should remain below 5%
- No sustained patterns of failed attempts from multiple IPs
- Security monitoring should alert on anomalous patterns

## Impact Assessment
- **Security Risk**: HIGH - Potential account compromise
- **Affected Accounts**: Investigation needed to identify targeted accounts
- **Business Impact**: Risk of unauthorized access to veteran data
- **Immediate Action Required**: Yes

## Evidence/Metrics
- Authentication failure logs showing spike
- IP address analysis needed
- User account targeting patterns
- Geographic distribution of attempts
- Time window: Past 2 hours

## Immediate Actions Taken
- [ ] Security team notified
- [ ] Monitoring increased
- [ ] IP analysis initiated

## Investigation Steps
1. Analyze authentication logs for patterns
2. Identify targeted user accounts
3. Geo-locate suspicious IP addresses
4. Check for compromised credentials in known breaches
5. Review rate limiting effectiveness
6. Consider temporary IP blocking if warranted

## Acceptance Criteria
- [ ] Full analysis of attack pattern completed
- [ ] Affected accounts identified and secured
- [ ] Rate limiting/security controls enhanced
- [ ] Incident documentation completed
- [ ] Security team review and sign-off
- [ ] Monitoring improvements implemented

## Labels
`security`, `critical`, `authentication`, `incident`, `immediate-action`

## Escalation
- **Security Team**: @security-team
- **On-Call**: @platform-sre-oncall
- **Incident Commander**: TBD based on severity assessment
```

### 4. Maintenance/Enhancement Template

**Copilot Prompt:**
```
Generate a maintenance ticket for:
- Service: vets-api
- Task: Upgrade Redis version for security patches
- Priority: Medium
- Planning required: Yes
```

**Expected Output:**
```markdown
## Issue Type
Maintenance

## Service/Component
vets-api - Redis Infrastructure

## Priority
Medium

## Description
Upgrade Redis version from 6.2.x to 6.2.14 to apply critical security patches and performance improvements. Current version has known vulnerabilities that should be addressed.

## Current State
- Redis version: 6.2.6
- Known vulnerabilities: CVE-2023-XXXX, CVE-2023-YYYY
- Performance issues with memory management
- No immediate service impact but security risk

## Target State
- Redis version: 6.2.14 (latest stable)
- Security vulnerabilities patched
- Improved memory management
- Zero downtime upgrade process

## Business Justification
- Security compliance requirements
- Performance optimization
- Alignment with VA security standards
- Proactive maintenance vs reactive patching

## Planning Requirements
- [ ] Maintenance window coordination
- [ ] Backup and recovery plan
- [ ] Rollback procedures
- [ ] Performance testing plan
- [ ] Stakeholder notification

## Implementation Plan
1. **Pre-upgrade (Week 1)**
   - Full Redis backup
   - Performance baseline establishment
   - Test environment upgrade and validation
   
2. **Upgrade Execution (Week 2)**
   - Coordinate maintenance window
   - Execute rolling upgrade (primary/replica)
   - Validate functionality post-upgrade
   
3. **Post-upgrade (Week 3)**
   - Performance monitoring
   - Security vulnerability validation
   - Documentation updates

## Risk Assessment
- **Low Risk**: Well-tested upgrade path
- **Mitigation**: Comprehensive testing in staging
- **Rollback Plan**: Previous version available for quick rollback
- **Service Impact**: Minimal (rolling upgrade)

## Success Criteria
- [ ] Redis upgraded to 6.2.14 successfully
- [ ] All security vulnerabilities resolved
- [ ] Performance metrics equal or better than baseline
- [ ] Zero unplanned downtime during upgrade
- [ ] All applications connecting successfully
- [ ] Monitoring and alerting functional

## Timeline
- **Planning**: 1 week
- **Testing**: 1 week  
- **Execution**: 2-hour maintenance window
- **Validation**: 1 week monitoring

## Labels
`maintenance`, `redis`, `security`, `infrastructure`, `planned`

## Dependencies
- Infrastructure team coordination
- Application team testing
- Security team validation
```

### 5. Monitoring/Alert Template

**Copilot Prompt:**
```
Generate a monitoring enhancement ticket for:
- Service: vets-api
- Enhancement: Add alerting for Sidekiq queue depth
- Priority: Low
- Improvement type: Proactive monitoring
```

**Expected Output:**
```markdown
## Issue Type
Enhancement - Monitoring

## Service/Component
vets-api - Sidekiq Background Jobs

## Priority
Low

## Description
Implement proactive monitoring and alerting for Sidekiq queue depth to prevent job backlog issues before they impact users. Currently we rely on reactive monitoring after problems occur.

## Current State
- Sidekiq queues monitored manually
- No automated alerting for queue depth
- Issues discovered after user impact
- Limited visibility into job processing trends

## Proposed Enhancement
- Automated alerts for queue depth thresholds
- Trending analysis for job processing rates
- Proactive notifications before SLA impact
- Dashboard improvements for queue visibility

## Business Value
- Prevent user-facing issues from job backlogs
- Improve operational efficiency
- Reduce mean time to detection (MTTD)
- Better capacity planning for background jobs

## Technical Requirements
- DataDog integration for Sidekiq metrics
- Alert thresholds based on historical analysis
- Escalation paths for different severity levels
- Documentation for on-call response

## Implementation Details
1. **Metrics Collection**
   - Queue depth by queue name
   - Job processing rate trends
   - Failed job rate monitoring
   - Worker utilization metrics

2. **Alert Configuration**
   - Warning: >1000 jobs in default queue
   - Critical: >5000 jobs or 15+ minute processing delay
   - Failed job rate: >5% over 10 minutes
   - Worker saturation: >90% for 5 minutes

3. **Dashboard Updates**
   - Real-time queue depth visualization
   - Historical trending graphs
   - Queue processing rate metrics
   - Failed job tracking

## Acceptance Criteria
- [ ] DataDog alerts configured for all critical queues
- [ ] Alert thresholds tested and validated
- [ ] On-call runbook updated with response procedures
- [ ] Dashboard provides clear queue visibility
- [ ] Escalation paths documented and tested
- [ ] 30-day trial period with alert tuning

## Success Metrics
- Reduce MTTD for queue issues by 50%
- Zero queue-related user impacts
- <2 false positive alerts per week
- 100% alert coverage for critical queues

## Labels
`enhancement`, `monitoring`, `sidekiq`, `proactive`, `low-priority`

## Timeline
- **Research**: 1 week
- **Implementation**: 2 weeks
- **Testing**: 1 week
- **Rollout**: 1 week
- **Monitoring**: 4 weeks
```

## Usage Guidelines

### For Copilot Users:
1. Choose the appropriate template based on issue type
2. Customize the prompt with specific details
3. Review and edit the generated output
4. Add actual links, timestamps, and specific data
5. Assign to appropriate team members

### Template Customization:
- Replace placeholder values with actual data
- Update links to point to real dashboards/logs
- Adjust priority based on actual business impact
- Add specific team mentions and escalation paths

### Quality Checklist:
- [ ] Title clearly describes the issue
- [ ] Priority matches business impact
- [ ] Acceptance criteria are specific and measurable
- [ ] Appropriate labels applied
- [ ] Evidence/metrics section has actual links
- [ ] Team assignments and escalation paths included

## Integration with CLAUDE.md

These templates work best when combined with the CLAUDE.md guidance:
- Follow vets-api architectural patterns
- Include security and compliance considerations
- Reference appropriate modules and services
- Use established coding and operational patterns
- Align with federal requirements and VA standards