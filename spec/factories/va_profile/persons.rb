# frozen_string_literal: true

FactoryBot.define do
  factory :person, class: 'VAProfile::Models::Person' do
    addresses   { [build(:va_profile_address), build(:va_profile_address, :mailing)] }
    emails      { [build(:email)] }
    telephones  { [build(:telephone)] }
    source_date { '2018-04-09T11:52:03-06:00' }
    created_at  { '2017-04-09T11:52:03-06:00' }
    updated_at  { '2017-04-09T11:52:03-06:00' }
    vet360_id { '12345' }
  end
end
