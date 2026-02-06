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
      code { 'DOC202' }
      detail { 'Image failed to process' }
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

  factory :min_nod_v2_issues_length_overflow, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_min_long_issues_desc.json' }
  end

  factory :min_nod_v2_6_issues, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_min_6_issues.json' }
  end

  factory :min_nod_v2_long_rep_name, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_min_long_rep_name.json' }
  end

  factory :min_nod_v2_long_email, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_min_long_email.json' }
  end

  factory :min_nod_v2_extension_request, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'decision_reviews/v2/valid_10182_min_extension_request.json' }
  end

  




  # Notice of Disagreements API v0 NODs
  factory :notice_of_disagreement_v0,
          class: 'AppealsApi::NoticeOfDisagreement', parent: :notice_of_disagreement_v2 do
    api_version { 'V0' }
    auth_headers { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182.json' }
    after(:build) do |nod, attrs|
      nod.form_data['data']['attributes']['veteran']['icn'] = attrs.veteran_icn if attrs.veteran_icn.present?
      nod
    end
  end

  factory :extra_notice_of_disagreement_v0,
          class: 'AppealsApi::NoticeOfDisagreement', parent: :extra_notice_of_disagreement_v2 do
    api_version { 'V0' }
    auth_headers { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182_headers.json' }
    form_data { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182_extra.json' }
    after(:build) do |nod, attrs|
      nod.form_data['data']['attributes']['veteran']['icn'] = attrs.veteran_icn if attrs.veteran_icn.present?
      nod
    end
  end

  factory :minimal_notice_of_disagreement_v0,
          class: 'AppealsApi::NoticeOfDisagreement', parent: :minimal_notice_of_disagreement_v2 do
    api_version { 'V0' }
    auth_headers { {} }
    form_data { FixtureHelpers.fixture_as_json 'notice_of_disagreements/v0/valid_10182_minimum.json' }
    after(:build) do |nod, attrs|
      nod.form_data['data']['attributes']['veteran']['icn'] = attrs.veteran_icn if attrs.veteran_icn.present?
      nod
    end
  end
end
