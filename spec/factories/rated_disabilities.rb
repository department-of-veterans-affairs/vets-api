# frozen_string_literal: true

require 'disability_compensation/responses/rated_disabilities_response'

FactoryBot.define do
  factory :rated_disability, class: 'DisabilityCompensation::ApiProvider::RatedDisability' do
    decision_code { 'SVCCONNCTED' }
    decision_text { 'Service Connected' }
    diagnostic_code { 5238 }
    effective_date { DateTime.new(2018, 3, 27) }
    maximum_rating_percentage { nil }
    name { 'Diabetes mellitus0' }
    rated_disability_id { '1' }
    rating_decision_id { '0' }
    rating_percentage { 50 }
    related_disability_date { DateTime.new(2024, 6, 18) }
    special_issues { [] }

    initialize_with { new(attributes) }
  end

  factory :rated_disabilities_response, class: 'DisabilityCompensation::ApiProvider::RatedDisabilitiesResponse' do
    initialize_with { new(rated_disabilities: [build(:rated_disability)]) }
  end
end
