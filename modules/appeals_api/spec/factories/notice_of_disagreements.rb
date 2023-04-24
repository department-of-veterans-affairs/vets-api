# frozen_string_literal: true

FactoryBot.define do
  factory :notice_of_disagreement, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v1/valid_10182_headers.json'.split('/')).to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v1/valid_10182.json'.split('/')).to_s))
    end
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
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v1/valid_10182_headers_minimum.json'.split('/'))
                          .to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v1/valid_10182_minimum.json'.split('/')).to_s))
    end
    board_review_option { 'evidence_submission' } # set manually in the controller
  end

  factory :notice_of_disagreement_v2, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_10182_headers.json'.split('/')).to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_10182.json'.split('/')).to_s))
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
    api_version { 'V2' }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_10182_headers_extra.json'.split('/'))
        .to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_10182_extra.json'.split('/')).to_s))
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

  factory :minimal_notice_of_disagreement_v2, class: 'AppealsApi::NoticeOfDisagreement' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_10182_headers.json'.split('/')).to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_10182_minimum.json'.split('/')).to_s))
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

  factory :notice_of_disagreement_v0,
          class: 'AppealsApi::NoticeOfDisagreement', parent: :notice_of_disagreement_v2 do
    api_version { 'V0' }
  end

  factory :extra_notice_of_disagreement_v0,
          class: 'AppealsApi::NoticeOfDisagreement', parent: :extra_notice_of_disagreement_v2 do
    api_version { 'V0' }
  end

  factory :minimal_notice_of_disagreement_v0,
          class: 'AppealsApi::NoticeOfDisagreement', parent: :minimal_notice_of_disagreement_v2 do
    api_version { 'V0' }
  end
end
