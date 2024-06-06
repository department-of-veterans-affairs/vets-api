# frozen_string_literal: true

FactoryBot.define do
  factory :flagged_veteran_representative_contact_data,
          class: 'RepresentationManagement::FlaggedVeteranRepresentativeContactData' do
    ip_address { '192.168.1.1' }
    representative_id { '1' }
    flag_type { 'phone_number' }
    flagged_value { '1234567890' }

    trait :flagged_email do
      flag_type { 'email' }
      flagged_value { 'example@email.com' }
    end
  end
end
