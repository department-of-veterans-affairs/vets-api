# Accredited Entities Synchronization Playbook/Incident Response Plan

## Product Description

**Product Overview:** The Accredited Entities Synchronization feature is a critical background job system that maintains up-to-date records of accredited representatives (attorneys, agents, VSO representatives) by synchronizing data from the GCLAWS API. This system runs daily and ensures Veterans have access to current information about accredited representatives who can assist them with benefits claims.

**Key Components:**

- Daily synchronization job (`AccreditedEntitiesQueueUpdates`) running at 4:00 AM ET
- Address validation job (`AccreditedIndividualsUpdate`) using VAProfile services
- Data integrity checks to prevent unexpected data loss
- Slack notifications for monitoring and alerts

## Contacts

- _All team members can also be reached via the Accredited Representation Management team DSVA Slack channel: [`#benefits-representation-management`](https://dsva.slack.com/archives/C05L6HSJLHM)_
- _Automated notifications are sent to: [`#benefits-representation-management-notifications`](https://dsva.slack.com/archives/C05L6HSJLHM)_

### Team Members

- DSVA Product Lead: Jennifer Bertsch, jennifer.bertsch@va.gov
- Team Product Manager: Lindsay Li-Smith, lindsay.li-smith@oddball.io
- [Full team roster](https://github.com/department-of-veterans-affairs/va.gov-team/tree/master/products/accredited-representation-management#team-members)

### Outage Contacts:

- Accredited Representation Management team Tech Lead: Holden Hinkle, holden.hinkle@oddball.io
- Accredited Representation Management team Backend Engineer: Josh Fike, josh.fike@oddball.io
- Accredited Representation Management team Frontend Engineer: Colin O'Sullivan, colin.osullivan@adhocteam.us
- Accredited Representation Management team Frontend Engineer: Peri McLaren, peri.mclaren@adhocteam.us

## Troubleshooting

### Common Issues and Symptoms

#### 1. Count Validation Failures

**Symptoms:**

- Slack alert: "Count decreased by more than X% - skipping update"
- No new data imported despite GCLAWS API being available
- Historical counts showing unexpected drops

**Immediate Actions:**

1. Check GCLAWS API status and recent changes
2. Review `AccreditationApiEntityCount` records for historical trends
3. Verify if decrease is legitimate (e.g., data cleanup at source)

**Resolution:**

- If decrease is expected: Force update using specific entity types

```ruby
# Force update for specific entity types
RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(['agents'])
RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(['attorneys'])
# Representatives and VSOs must be processed together
RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(['representatives', 'veteran_service_organizations'])
```

#### 2. Address Validation Failures

**Symptoms:**

- Individual records not updating with geocoding data
- Errors in `AccreditedIndividualsUpdate` logs
- Records with zero latitude/longitude values

**Immediate Actions:**

1. Check VAProfile service status
2. Review specific address formats causing failures
3. Monitor retry attempts in logs

**Resolution:**

- Check feature flag status: `Flipper.enabled?(:remove_pciu)`
- Manually process failed records:

```ruby
record = AccreditedIndividual.find(id)
RepresentationManagement::AccreditedIndividualsUpdate.new.perform([{
  id: record.id,
  address: record.raw_address
}.to_json])
```

#### 3. Job Performance Issues

**Symptoms:**

- Jobs taking longer than expected (normal: 2-4 hours)
- Sidekiq queue backing up
- Memory issues on worker nodes

**Immediate Actions:**

1. Check Sidekiq queue depth
2. Monitor worker memory usage
3. Review batch size settings

**Resolution:**

- Adjust SLICE_SIZE constant if needed (default: 30)
- Scale Sidekiq workers if necessary
- Check for API rate limiting

#### 4. Missing VSO Associations

**Symptoms:**

- Representatives not linked to their VSOs
- Accreditation records missing
- Errors mentioning "VSO not found for ogc_id"

**Immediate Actions:**

1. Verify VSOs were processed before representatives
2. Check for VSO records in database
3. Review job execution order

**Resolution:**

```ruby
# Verify VSO exists
vso = AccreditedOrganization.find_by(ogc_id: 'vso_id')

# Check representative associations
rep = AccreditedIndividual.find_by(ogc_id: 'rep_id', individual_type: 'representative')
rep.accredited_organizations

# Manually create association if needed
Accreditation.find_or_create_by(
  accredited_individual_id: rep.id,
  accredited_organization_id: vso.id
)
```

### Errors and Metrics

#### Error Logging

- **Rails Logger:** Application logs capture detailed error information
- **Slack Notifications:** Production errors automatically posted to `#benefits-representation-management-notifications`
- **Sentry Integration:** Runtime errors and exceptions tracked in Sentry

#### Performance Metrics

- **Sidekiq Monitoring:** Monitor job execution times and queue depths
- **Database Metrics:** Track record counts and update rates
- **API Response Times:** Monitor GCLAWS API performance

#### Key Metrics to Monitor

1. **Entity Counts:**

   - Total agents, attorneys, representatives, VSOs
   - Daily count changes
   - Validation threshold breaches

2. **Job Performance:**

   - Total execution time
   - Records processed per minute
   - Address validation success rate

3. **Data Quality:**
   - Records with valid geocoding
   - Failed address validations
   - Missing associations

### Debug Commands

```ruby
# Check current entity counts from API
RepresentationManagement::AccreditationApiEntityCount.new.api_counts

# View stored historical counts
AccreditationApiEntityCount.order(created_at: :desc).limit(7)

# Check job status
Sidekiq::Queue.new.size
Sidekiq::RetrySet.new.size

# Verify data integrity
AccreditedIndividual.where(lat: nil, long: nil).count
AccreditedIndividual.where(individual_type: 'representative').includes(:accredited_organizations).where(accredited_organizations: { id: nil }).count
```

### Flipper Features and Rollback

- **remove_pciu**: Toggles between V2 and V3 VAProfile address validation services
  - V2: Uses `VAProfile::AddressValidation::Service`
  - V3: Uses `VAProfile::V3::AddressValidation::Service`

### Emergency Procedures

#### Complete Job Failure

1. **Immediate Response:**

   - Check Sidekiq dead set for failed jobs
   - Review error logs for root cause
   - Notify team via Slack

2. **Recovery:**
   - Fix underlying issue
   - Manually trigger job if within business hours
   - Monitor completion

#### Data Corruption

1. **Detection:**

   - Unexpected record deletions
   - Invalid data in updated records
   - Association mismatches

2. **Response:**
   - Stop job execution immediately
   - Restore from database backup if necessary
   - Investigate root cause
   - Implement additional validation

## Scheduled Maintenance

### Daily Operations

- Job runs automatically at 4:00 AM ET
- Monitor Slack channel for completion report
- Review any validation failures

### Weekly Checks

- Review job execution times for trends
- Check address validation success rates
- Verify entity count trends

### Monthly Reviews

- Analyze data quality metrics
- Review and adjust thresholds if needed
- Update documentation as necessary

## Security Considerations

### Data Handling

- No PII/PHI is stored in logs
- Address data is validated but not exposed
- API credentials stored securely in environment variables

### Access Control

- GCLAWS API access restricted by credentials
- VAProfile API access requires authentication
- Database access follows standard Rails security practices

## Configuration Requirements

### Environment Variables

- GCLAWS API credentials
- VAProfile API credentials
- Slack webhook URL for notifications

### Settings

- `DECREASE_THRESHOLD`: Maximum allowed percentage decrease (negative value)
- `SLICE_SIZE`: Batch size for address validation
- Periodic job schedule in `lib/periodic_jobs.rb`

## Dependencies

### External Services

1. **GCLAWS API**

   - Provides accredited entity data
   - Must be accessible from workers
   - Rate limits may apply

2. **VAProfile Address Validation Service**

   - Validates and geocodes addresses
   - Feature flag controls version
   - May have intermittent issues with P.O. Box addresses

3. **Slack Webhooks**
   - Used for notifications
   - Non-critical (job continues if Slack fails)

### Internal Dependencies

- PostgreSQL database
- Sidekiq/Redis
- Rails application framework

## Recovery Procedures

### Restoring from Backup

If data corruption occurs:

1. Identify the last known good state
2. Restore database tables:
   - `accredited_individuals`
   - `accredited_organizations`
   - `accreditations`
   - `accreditation_api_entity_counts`
3. Re-run synchronization job

### Manual Data Recovery

For partial failures:

```ruby
# Reprocess specific entity types
RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(['agents'])

# Revalidate addresses for specific records
individuals = AccreditedIndividual.where(lat: nil).limit(100)
json_data = individuals.map do |ind|
  { id: ind.id, address: ind.raw_address }
end.to_json
RepresentationManagement::AccreditedIndividualsUpdate.perform_async(json_data)
```

## Post-Incident Review

After any incident:

1. Document timeline and impact
2. Identify root cause
3. Update monitoring/alerts
4. Improve validation logic
5. Update this playbook
6. Share learnings with team

## Additional Resources

- [GCLAWS API Documentation]
- [VAProfile Integration Guide]
- [Sidekiq Best Practices](https://github.com/mperham/sidekiq/wiki/Best-Practices)
- [Team Confluence Space]
