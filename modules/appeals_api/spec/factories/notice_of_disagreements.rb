# frozen_string_literal: true

require_relative '../support/fixture_helpers'

FactoryBot.define do
  # Decision Reviews API v1 NODs
  factory :notice_of_disagreement, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v1/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v1/valid_10182.json' }
    board_review_option { 'hearing' } # set manually in the controller
    trait :status_error do
      status { 'error' }
    end
    trait :board_review_hearing do
      board_review_option { 'hearing' }
    end
  end

  factory :minimal_notice_of_disagreement, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v1/valid_10182_headers_minimum.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v1/valid_10182_minimum.json' }
    board_review_option { 'evidence_submission' } # set manually in the controller
  end

  # Decision Reviews API v2 NODs
  factory :notice_of_disagreement_v2, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182.json' }
    trait :board_review_hearing do
      board_review_option { 'hearing' }
    end
    trait :board_review_evidence_submission do
      board_review_option { 'evidence_submission' }
    end
    trait :board_review_direct_review do
      board_review_option { 'direct_review' }
    end
  end

  factory :extra_notice_of_disagreement_v2, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_headers_extra.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_extra.json' }
    trait :board_review_hearing do
      board_review_option { 'hearing' }
    end
    trait :board_review_evidence_submission do
      board_review_option { 'evidence_submission' }
    end
    trait :board_review_direct_review do
      board_review_option { 'direct_review' }
    end
  end

  factory :minimal_notice_of_disagreement_v2, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_minimum.json' }
    trait :board_review_hearing do
      board_review_option { 'hearing' }
    end
    trait :board_review_evidence_submission do
      board_review_option { 'evidence_submission' }
    end
    trait :board_review_direct_review do
      board_review_option { 'direct_review' }
    end
  end

  # Notice of Disagreements API v0 NODs
  factory :notice_of_disagreement_v0,
          class: 'AppealsApi::NoticeOfDisagreement', parent: :notice_of_disagreement_v2 do
    api_version { 'V0' }
    auth_headers { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182.json' }
  end

  factory :extra_notice_of_disagreement_v0,
          class: 'AppealsApi::NoticeOfDisagreement', parent: :extra_notice_of_disagreement_v2 do
    api_version { 'V0' }
    auth_headers { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182_headers_extra.json' }
    form_data { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182_extra.json' }
  end

  factory :minimal_notice_of_disagreement_v0,
          class: 'AppealsApi::NoticeOfDisagreement', parent: :minimal_notice_of_disagreement_v2 do
    api_version { 'V0' }
    auth_headers { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182_minimum.json' }
  end
end
