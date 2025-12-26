# frozen_string_literal: true

require_relative '../support/fixture_helpers'

FactoryBot.define do
  # Decision Reviews API v1 HLRs
  # HLRv1 may be all-but-removed, but records still exist in prod and we want to ensure it's represented in specs
  factory :higher_level_review_v1, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v1/valid_200996_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v1/valid_200996.json' }
  end

  # Decision Reviews API v2 HLRs
  factory :higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200996_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200996.json' }

    trait :status_error do
      status { 'error' }
      code { 'DOC202' }
      detail { 'Image failed to process' }
    end
  end

  factory :extra_higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      FixtureHelpers.fixture_as_json('decision_reviews/v2/valid_200996_headers_extra.json')
                    .transform_values(&:strip)
    end
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200996_extra.json' }
  end

  factory :minimal_higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200996_headers_minimum.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_200996_minimum.json' }
  end

  # Higher-Level Reviews API v0 HLRs
  factory :higher_level_review_v0,
          class: 'AppealsApi::HigherLevelReview', parent: :higher_level_review_v2 do
    api_version { 'V0' }
    auth_headers { FixtureHelpers.fixture_as_json 'higher_level_reviews/v0/valid_200996_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'higher_level_reviews/v0/valid_200996.json' }
    after(:build) do |hlr, attrs|
      hlr.form_data['data']['attributes']['veteran']['icn'] = attrs.veteran_icn if attrs.veteran_icn.present?
      hlr
    end
  end

  factory :extra_higher_level_review_v0,
          class: 'AppealsApi::HigherLevelReview', parent: :extra_higher_level_review_v2 do
    api_version { 'V0' }
    auth_headers { FixtureHelpers.fixture_as_json 'higher_level_reviews/v0/valid_200996_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'higher_level_reviews/v0/valid_200996_extra.json' }
    after(:build) do |hlr, attrs|
      hlr.form_data['data']['attributes']['veteran']['icn'] = attrs.veteran_icn if attrs.veteran_icn.present?
      hlr
    end
  end

  factory :minimal_higher_level_review_v0,
          class: 'AppealsApi::HigherLevelReview', parent: :minimal_higher_level_review_v2 do
    api_version { 'V0' }
    auth_headers { {} }
    form_data { FixtureHelpers.fixture_as_json 'higher_level_reviews/v0/valid_200996_minimum.json' }
    after(:build) do |hlr, attrs|
      hlr.form_data['data']['attributes']['veteran']['icn'] = attrs.veteran_icn if attrs.veteran_icn.present?
      hlr
    end
  end
end
