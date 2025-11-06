# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
#
# Sample response from https://api-reference.pagerduty.com/#!/Services/get_services
#
def valid_service
  [
    {
      'id' => 'P9S4RFU',
      'name' => 'External: Appeals',
      'description' => 'https://github.com/department-of-veterans-affairs/devops/blob/master/docs/External%20Service%20Integrations/Appeals.md',
      'auto_resolve_timeout' => 14_400,
      'acknowledgement_timeout' => nil,
      'created_at' => '2019-01-10T17:18:09-05:00',
      'status' => 'active',
      'last_incident_timestamp' => '2019-03-01T02:55:55-05:00',
      'teams' => [],
      'incident_urgency_rule' => {
        'type' => 'use_support_hours',
        'during_support_hours' => {
          'type' => 'constant',
          'urgency' => 'high'
        },
        'outside_support_hours' => {
          'type' => 'constant',
          'urgency' => 'low'
        }
      },
      'scheduled_actions' => [],
      'support_hours' => {
        'type' => 'fixed_time_per_day',
        'time_zone' => 'America/New_York',
        'days_of_week' => [
          1,
          2,
          3,
          4,
          5
        ],
        'start_time' => '09:00:00',
        'end_time' => '17:00:00'
      },
      'escalation_policy' => {
        'id' => 'P6CEGGU',
        'type' => 'escalation_policy_reference',
        'summary' => 'Kraken Critical',
        'self' => 'https://api.pagerduty.com/escalation_policies/P6CEGGU',
        'html_url' => 'https://ecc.pagerduty.com/escalation_policies/P6CEGGU'
      },
      'addons' => [],
      'alert_creation' => 'create_alerts_and_incidents',
      'alert_grouping' => nil,
      'alert_grouping_timeout' => nil,
      'integrations' => [
        {
          'id' => 'P3SDLYP',
          'type' => 'generic_events_api_inbound_integration_reference',
          'summary' => 'Prometheus: Appeals',
          'self' => 'https://api.pagerduty.com/services/P9S4RFU/integrations/P3SDLYP',
          'html_url' => 'https://ecc.pagerduty.com/services/P9S4RFU/integrations/P3SDLYP'
        }
      ],
      'response_play' => nil,
      'type' => 'service',
      'summary' => 'External: Appeals',
      'self' => 'https://api.pagerduty.com/services/P9S4RFU',
      'html_url' => 'https://ecc.pagerduty.com/services/P9S4RFU'
    }
  ]
end

# Sample response from https://api-reference.pagerduty.com/#!/Services/get_services
# with `name: Staging: ...`
#
def valid_staging_service
  [
    {
      'id' => 'P9S4RFU',
      'name' => 'Staging: External: Appeals',
      'description' => 'https://github.com/department-of-veterans-affairs/devops/blob/master/docs/External%20Service%20Integrations/Appeals.md',
      'auto_resolve_timeout' => 14_400,
      'acknowledgement_timeout' => nil,
      'created_at' => '2019-01-10T17:18:09-05:00',
      'status' => 'active',
      'last_incident_timestamp' => '2019-03-01T02:55:55-05:00',
      'teams' => [],
      'incident_urgency_rule' => {
        'type' => 'use_support_hours',
        'during_support_hours' => {
          'type' => 'constant',
          'urgency' => 'high'
        },
        'outside_support_hours' => {
          'type' => 'constant',
          'urgency' => 'low'
        }
      },
      'scheduled_actions' => [],
      'support_hours' => {
        'type' => 'fixed_time_per_day',
        'time_zone' => 'America/New_York',
        'days_of_week' => [
          1,
          2,
          3,
          4,
          5
        ],
        'start_time' => '09:00:00',
        'end_time' => '17:00:00'
      },
      'escalation_policy' => {
        'id' => 'P6CEGGU',
        'type' => 'escalation_policy_reference',
        'summary' => 'Kraken Critical',
        'self' => 'https://api.pagerduty.com/escalation_policies/P6CEGGU',
        'html_url' => 'https://ecc.pagerduty.com/escalation_policies/P6CEGGU'
      },
      'addons' => [],
      'alert_creation' => 'create_alerts_and_incidents',
      'alert_grouping' => nil,
      'alert_grouping_timeout' => nil,
      'integrations' => [
        {
          'id' => 'P3SDLYP',
          'type' => 'generic_events_api_inbound_integration_reference',
          'summary' => 'Prometheus: Appeals',
          'self' => 'https://api.pagerduty.com/services/P9S4RFU/integrations/P3SDLYP',
          'html_url' => 'https://ecc.pagerduty.com/services/P9S4RFU/integrations/P3SDLYP'
        }
      ],
      'response_play' => nil,
      'type' => 'service',
      'summary' => 'External: Appeals',
      'self' => 'https://api.pagerduty.com/services/P9S4RFU',
      'html_url' => 'https://ecc.pagerduty.com/services/P9S4RFU'
    }
  ]
end
# rubocop:enable Metrics/MethodLength
