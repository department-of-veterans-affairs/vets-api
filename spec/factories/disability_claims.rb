# frozen_string_literal: true
FactoryGirl.define do
  factory :disability_claim do
    user_uuid '1234'
    evss_id   1
    data      do
      fixture_file_name = "#{::Rails.root}/spec/fixtures/disability_claim/claim-detail.json"
      File.open(fixture_file_name, 'rb') do |f|
        raw_claim = f.read
        JSON.parse raw_claim
      end
    end
    updated_at { Time.current.utc }
  end
end
