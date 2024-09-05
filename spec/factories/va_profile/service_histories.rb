# frozen_string_literal: true

require 'va_profile/models/service_history'

FactoryBot.define do
  factory :service_history, class: 'VAProfile::Models::ServiceHistory' do
    begin_date { '2012-03-02' }
    branch_of_service { 'Army' }
    branch_of_service_code { 'A' }
    character_of_discharge_code { 'A' }
    deployments { [] }
    end_date { '2018-10-31' }
    personnel_category_type_code { 'N' }
    service_type { 'Military Service' }
    termination_reason_code { 'C' }
    termination_reason_text { 'Completion of Active Service period' }

    trait :with_deployments do
      deployments do
        [
          {
            'deployment_sequence_number' => 1,
            'deployment_begin_date' => '2004-11-15',
            'deployment_end_date' => '2005-10-25',
            'deployment_project_text' => 'Overseas Contingency Operation (OCO)',
            'deployment_project_code' => '9GF',
            'deployment_termination_reason_text' => 'Separation from personnel category or organization',
            'deployment_termination_reason_code' => 'S',
            'deployment_locations' => [
              {
                'deployment_location_sequence_number' => 2,
                'deployment_country_text' => 'Germany -- Added October 1990; formerly Germany, Berlin (BZ)',
                'deployment_country_code' => 'GM',
                'deployment_location_body_of_water_text' => 'DoD provided a NULL or blank value',
                'deployment_location_body_of_water_code' => 'DVN',
                'deployment_location_begin_date' => '2005-04-12',
                'deployment_location_end_date' => '2005-05-04',
                'deployment_location_termination_reason_text' => 'DoD provided a NULL or blank value',
                'deployment_location_termination_reason_code' => 'DVN'
              }
            ]
          }
        ]
      end
    end

    initialize_with { new(attributes) }
  end
end
