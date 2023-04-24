# frozen_string_literal: true

FactoryBot.define do
  # HLRv1 may be all-but-removed, but records still exist in prod and we want to ensure it's represented in specs
  factory :higher_level_review_v1, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V1' }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v1/valid_200996_headers.json'.split('/')).to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v1/valid_200996.json'.split('/')).to_s))
    end
  end

  factory :higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200996_headers.json'.split('/')).to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200996.json'.split('/')).to_s))
    end

    trait :status_error do
      status { 'error' }
    end
  end

  factory :extra_higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200996_headers_extra.json'.split('/'))
              .to_s)).transform_values(&:strip)
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200996_extra.json'.split('/')).to_s))
    end
  end

  factory :minimal_higher_level_review_v2, class: 'AppealsApi::HigherLevelReview' do
    id { SecureRandom.uuid }
    api_version { 'V2' }
    auth_headers do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200996_headers_minimum.json'.split('/'))
              .to_s))
    end
    form_data do
      JSON.parse(File
        .read(::Rails.root.join(*'/modules/appeals_api/spec/fixtures/v2/valid_200996_minimum.json'.split('/')).to_s))
    end
  end

  factory :higher_level_review_v0,
          class: 'AppealsApi::HigherLevelReview', parent: :higher_level_review_v2 do
    api_version { 'V0' }
  end

  factory :extra_higher_level_review_v0,
          class: 'AppealsApi::HigherLevelReview', parent: :extra_higher_level_review_v2 do
    api_version { 'V0' }
  end

  factory :minimal_higher_level_review_v0,
          class: 'AppealsApi::HigherLevelReview', parent: :minimal_higher_level_review_v2 do
    api_version { 'V0' }
  end
end
