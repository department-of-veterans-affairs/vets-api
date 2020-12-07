# frozen_string_literal: true

FactoryBot.define do
  factory :vaccine_registry, class: 'Vetext::V0::VaccineRegistry' do
    transient do
      user { build(:user, :mhv) }
    end

    trait :unauth_no_mvi do
      vaccine_interest { 'yes' }
      authenticated { true }
      date_vaccine_reeceived { '' }
      contact { true }
      contact_method { 'phone' }
      reason_undecided { '' }
      first_name { 'Jane' }
      last_name { 'Doe' }
      date_of_birth { '2/2/1952' }
      phone { '555-555-1234' }
      email { 'jane.doe@email.com' }
      patient_ssn { '000-00-0022' }

      initialize_with { new(attributes, nil) }
    end

    trait :auth do
      vaccine_interest { 'yes' }
      authenticated { true }
      date_vaccine_received { '' }
      contact { true }
      contact_method { 'phone' }
      reason_undecided { '' }
      phone { '555-555-1234' }
      email { 'judy.morrison@email.com' }

      initialize_with { new(attributes, user) }
    end
  end
end
