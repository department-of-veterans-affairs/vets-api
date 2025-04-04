# frozen_string_literal: true

FactoryBot.define do
  factory :evss_claim do
    user_uuid { SecureRandom.uuid }
    evss_id   { 1 }

    data do
      fixture_file_name = Rails.root.join(*'/spec/fixtures/evss_claim/claim-detail.json'.split('/')).to_s
      File.open(fixture_file_name, 'rb') do |f|
        raw_claim = f.read
        JSON.parse(raw_claim).deep_transform_keys!(&:underscore)
      end.merge('min_est_claim_date' => '01/01/2023', 'max_est_claim_date' => '12/31/2023')
    end

    list_data do
      fixture_file_name = Rails.root.join(*'/spec/fixtures/evss_claim/claim-list.json'.split('/')).to_s
      File.open(fixture_file_name, 'rb') do |f|
        raw_claim = f.read
        JSON.parse(raw_claim).deep_transform_keys!(&:underscore)
      end
    end

    trait :with_user_account do
      association :user_account
    end

    trait :bad_data do
      data do
        fixture_file_name = Rails.root.join(*'/spec/fixtures/evss_claim/claim-detail.json'.split('/')).to_s
        File.open(fixture_file_name, 'rb') do |f|
          raw_claim = f.read
          JSON.parse(raw_claim).deep_transform_keys!(&:underscore)
        end.merge('development_letter_sent' => 'Test')
      end
    end
  end
end
