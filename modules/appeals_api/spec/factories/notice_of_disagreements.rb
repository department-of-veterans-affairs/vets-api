# frozen_string_literal: true

FactoryBot.define do
  factory :notice_of_disagreement, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_10182_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_10182.json"
    end
    board_review_option { 'hearing' } # set manually in the controller
    trait :status_error do
      status { 'error' }
    end
    trait :status_received do
      status { 'submitted' }
    end
    trait :status_completed do
      status { AppealsApi::NoticeOfDisagreement::COMPLETE_STATUSES.sample }
    end
    trait :completed_a_day_ago do
      updated_at { 1.day.ago }
      status { AppealsApi::NoticeOfDisagreement::COMPLETE_STATUSES.sample }
    end
    trait :completed_a_week_ago do
      updated_at { 8.days.ago }
      status { AppealsApi::NoticeOfDisagreement::COMPLETE_STATUSES.sample }
    end
    trait :board_review_hearing do
      board_review_option { 'hearing' }
    end
  end

  factory :minimal_notice_of_disagreement, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_10182_headers_minimum.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v1/valid_10182_minimum.json"
    end
    board_review_option { 'evidence_submission' } # set manually in the controller
  end

  factory :notice_of_disagreement_v2, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_10182_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_10182.json"
    end

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
    auth_headers do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_10182_headers.json"
    end
    form_data do
      JSON.parse File.read "#{::Rails.root}/modules/appeals_api/spec/fixtures/v2/valid_10182_extra.json"
    end

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
end
