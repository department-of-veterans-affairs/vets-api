# GitHub Copilot Prompts for SRE Ticket Templates

## Overview
This document provides a comprehensive set of GitHub Copilot prompts designed to help engineers and product managers rapidly generate standardized SRE team tickets. These prompts leverage Copilot's AI capabilities to create consistent, well-structured tickets that follow best practices.

## Basic Ticket Template Prompt

### Standard SRE Ticket
```
Generate a GitHub issue for an SRE ticket with the following structure:
- Title: [Brief, descriptive title]
- User Story: As a [role], I want [functionality] so that [benefit]
- Issue Description: [Detailed explanation of the issue/request]
- Tasks: [Numbered list of specific tasks to complete]
- Acceptance Criteria: [Checklist of criteria that must be met]
- Technical Requirements: [Any technical specifications or constraints]
- Dependencies: [List any dependencies or blockers]
- Impact: [Describe the impact on users/systems]
- Priority: [High/Medium/Low]
- Estimated Effort: [T-shirt size: S/M/L/XL]
```

## Specialized Prompt Templates

### 1. Infrastructure Change Request
```
Create an SRE infrastructure change ticket:

## User Story
As a [system/service name] owner, I need [infrastructure change] to [achieve goal/benefit]

## Issue Description
[Describe the current state and desired state]

## Tasks
- [ ] Review current infrastructure configuration
- [ ] Create implementation plan
- [ ] Test changes in staging environment
- [ ] Document rollback procedure
- [ ] Execute change in production
- [ ] Verify successful deployment
- [ ] Update documentation

## Acceptance Criteria
- [ ] Change implemented with zero downtime
- [ ] All tests pass in staging and production
- [ ] Monitoring alerts configured
- [ ] Documentation updated
- [ ] Rollback procedure tested

## Technical Requirements
- Environment: [staging/production]
- Services affected: [list services]
- Infrastructure components: [list components]
- Required permissions: [list permissions]

## Risk Assessment
- Risk level: [Low/Medium/High]
- Mitigation strategy: [describe strategy]
```

### 2. Incident Response Ticket
```
Generate an incident response ticket for SRE:

## Incident Summary
- Severity: [P1/P2/P3/P4]
- Services Affected: [list services]
- Start Time: [timestamp]
- Detection Method: [monitoring/user report/other]

## Issue Description
[Describe the incident, symptoms, and initial observations]

## Immediate Actions Taken
- [ ] Acknowledged incident
- [ ] Notified stakeholders
- [ ] Initiated incident response procedure
- [ ] [Other immediate actions]

## Investigation Tasks
- [ ] Analyze logs and metrics
- [ ] Identify root cause
- [ ] Document timeline of events
- [ ] Determine impact scope

## Resolution Tasks
- [ ] Implement fix
- [ ] Verify resolution
- [ ] Monitor for recurrence
- [ ] Update status page

## Post-Incident Tasks
- [ ] Conduct post-mortem
- [ ] Document lessons learned
- [ ] Create follow-up tickets for improvements
- [ ] Update runbooks

## Acceptance Criteria
- [ ] Service restored to normal operation
- [ ] Root cause identified and documented
- [ ] Post-mortem completed
- [ ] Action items created for prevention
```

### 3. Monitoring and Alerting Setup
```
Create an SRE monitoring setup ticket:

## User Story
As an SRE team member, I need monitoring for [service/component] to proactively detect and respond to issues

## Issue Description
Set up comprehensive monitoring and alerting for [describe what needs monitoring]

## Tasks
- [ ] Define key metrics and SLIs
- [ ] Configure metric collection
- [ ] Create dashboard(s)
- [ ] Set up alert rules
- [ ] Configure notification channels
- [ ] Test alert conditions
- [ ] Document alert response procedures

## Monitoring Requirements
### Metrics to Track
- [ ] Availability/Uptime
- [ ] Response time/Latency
- [ ] Error rate
- [ ] Throughput
- [ ] Resource utilization
- [ ] [Custom metrics]

### Alert Thresholds
- Critical: [define thresholds]
- Warning: [define thresholds]
- Info: [define thresholds]

## Acceptance Criteria
- [ ] All defined metrics are being collected
- [ ] Dashboard displays real-time data
- [ ] Alerts fire correctly when thresholds are breached
- [ ] Notifications reach appropriate channels
- [ ] Runbook created for alert response
```

### 4. Security Patch/Update
```
Generate a security patch ticket for SRE:

## Security Update Required
- CVE/Security Advisory: [identifier]
- Severity: [Critical/High/Medium/Low]
- Affected Components: [list components]
- Deadline: [date if applicable]

## Issue Description
[Describe the security vulnerability and its potential impact]

## Tasks
- [ ] Review security advisory details
- [ ] Identify all affected systems
- [ ] Test patch in development environment
- [ ] Create rollback plan
- [ ] Schedule maintenance window (if needed)
- [ ] Apply patch to staging
- [ ] Verify functionality in staging
- [ ] Apply patch to production
- [ ] Verify functionality in production
- [ ] Update security compliance documentation

## Testing Requirements
- [ ] Functional testing
- [ ] Performance testing
- [ ] Security validation
- [ ] Integration testing

## Acceptance Criteria
- [ ] All affected systems patched
- [ ] No functionality regression
- [ ] Security scan shows vulnerability resolved
- [ ] Documentation updated
- [ ] Compliance requirements met
```

### 5. Performance Optimization
```
Create a performance optimization ticket for SRE:

## User Story
As a user, I need [service/feature] to perform faster to improve my experience

## Current Performance Metrics
- Current response time: [measurement]
- Current throughput: [measurement]
- Current resource utilization: [measurement]
- Target improvements: [specify targets]

## Tasks
- [ ] Conduct performance profiling
- [ ] Identify bottlenecks
- [ ] Develop optimization plan
- [ ] Implement optimizations
- [ ] Run performance tests
- [ ] Compare before/after metrics
- [ ] Deploy to production
- [ ] Monitor performance post-deployment

## Technical Approach
- [ ] Database query optimization
- [ ] Caching implementation
- [ ] Code optimization
- [ ] Infrastructure scaling
- [ ] Load balancing improvements
- [ ] [Other optimizations]

## Acceptance Criteria
- [ ] Performance targets met or exceeded
- [ ] No functionality regression
- [ ] Performance tests pass
- [ ] Monitoring shows sustained improvement
- [ ] Documentation updated
```

## Advanced Prompt Techniques

### Context-Aware Prompting
```
Given the following context about our system:
- Technology stack: [e.g., Ruby on Rails, PostgreSQL, Redis]
- Deployment platform: [e.g., AWS, Kubernetes]
- Team size: [number]
- Current priorities: [list priorities]

Generate an SRE ticket for [specific need] that takes into account our technology constraints and team capacity.
```

### Template with Variables
```
Create an SRE ticket template where:
{{SERVICE_NAME}} = the service being modified
{{ENVIRONMENT}} = target environment
{{TEAM_NAME}} = responsible team
{{DUE_DATE}} = deadline for completion

The ticket should include standard SRE sections and reference these variables throughout.
```

## Prompt Validation Checklist

When using these prompts, ensure the generated ticket includes:
- [ ] Clear, actionable title
- [ ] Well-defined user story or problem statement
- [ ] Detailed description with context
- [ ] Specific, measurable tasks
- [ ] Testable acceptance criteria
- [ ] Technical requirements and constraints
- [ ] Impact assessment
- [ ] Priority and effort estimation

## Tips for Effective Prompt Usage

1. **Be Specific**: The more context you provide, the better the output
2. **Iterate**: Use the initial output as a starting point and refine
3. **Customize**: Adapt prompts to your team's specific needs and standards
4. **Review**: Always review and adjust generated content for accuracy
5. **Learn Patterns**: Save successful prompts for reuse

## Limitations and Considerations

### Known Limitations
- Copilot may not have context about your specific infrastructure
- Generated tickets may need adjustment for company-specific requirements
- Technical details should be verified for accuracy
- Security-sensitive information should never be included in prompts

### Best Practices
- Always review generated content before creating the actual ticket
- Supplement with specific technical details as needed
- Use prompts as a starting point, not the final product
- Keep sensitive information out of prompts
- Validate technical accuracy of generated content

## Example Workflow

1. **Initial Generation**: Use a basic prompt to create the ticket structure
2. **Enhancement**: Add specific details about your system
3. **Validation**: Check against your team's standards
4. **Refinement**: Adjust language and requirements as needed
5. **Review**: Have a team member review before submission

## Follow-up Actions

After using these prompts:
1. Track which prompts are most effective
2. Create team-specific prompt variations
3. Document successful patterns
4. Share improvements with the team
5. Continuously refine based on feedback

## Additional Resources

- [GitHub Copilot Documentation](https://docs.github.com/en/copilot)
- [SRE Best Practices](https://sre.google/sre-book/)
- Internal SRE team documentation and runbooks
- Team-specific ticket standards and requirements