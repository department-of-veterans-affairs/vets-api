# frozen_string_literal: true

FactoryBot.define do
  factory :supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    evidence_submission_indicated { true }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200995_headers.json'.split('/')).to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200995.json'.split('/')).to_s))
    end

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
      JSON.parse(File
        .read(
          ::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200995_headers_extra.json'.split('/')).to_s
        )).transform_values(&:strip)
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200995_extra.json'.split('/')).to_s))
    end
  end

  factory :minimal_supplemental_claim, class: 'AppealsApi::SupplementalClaim' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200995_headers_minimum.json'.split('/'))
        .to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200995.json'.split('/')).to_s))
    end
  end

  factory :supplemental_claim_v0,
          class: 'AppealsApi::SupplementalClaim', parent: :supplemental_claim do
    api_version { 'V0' }
  end

  factory :extra_supplemental_claim_v0,
          class: 'AppealsApi::SupplementalClaim', parent: :extra_supplemental_claim do
    api_version { 'V0' }
  end

  factory :minimal_supplemental_claim_v0,
          class: 'AppealsApi::SupplementalClaim', parent: :minimal_supplemental_claim do
    api_version { 'V0' }
  end
end
