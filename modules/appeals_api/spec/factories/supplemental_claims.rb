# frozen_string_literal: true

require_relative '../support/fixture_helpers'

FactoryBot.define do
  # Decision Reviews API v2 SCs
  factory :supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    evidence_submission_indicated { true }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200995_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200995.json' }

    trait :status_success do
      status { 'success' }
    end

    trait :status_error do
      status { 'error' }
    end

    trait :status_submitted do
      status { 'submitted' }
    end
  end

  factory :extra_supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    evidence_submission_indicated { true }
    auth_headers do
      FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200995_headers_extra.json')
                    .transform_values(&:strip)
    end
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200995_extra.json' }
  end

  factory :minimal_supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200995_headers_minimum.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200995.json' }
  end

  # Supplemental Claims API v0 SCs
  factory :supplemental_claim_v0,
          class: 'AppealsApi::SupplementalClaim', parent: :supplemental_claim do
    api_version { 'V0' }
    auth_headers { FixtureHelpers.fixture_as_json 'supplemental_claims/v0/valid_200995_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'supplemental_claims/v0/valid_200995.json' }
  end

  factory :extra_supplemental_claim_v0,
          class: 'AppealsApi::SupplementalClaim', parent: :extra_supplemental_claim do
    api_version { 'V0' }
    auth_headers { FixtureHelpers.fixture_as_json 'supplemental_claims/v0/valid_200995_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'supplemental_claims/v0/valid_200995_extra.json' }
  end

  factory :minimal_supplemental_claim_v0,
          class: 'AppealsApi::SupplementalClaim', parent: :minimal_supplemental_claim do
    api_version { 'V0' }
    form_data { FixtureHelpers.fixture_as_json 'supplemental_claims/v0/valid_200995.json' }
  end
end
