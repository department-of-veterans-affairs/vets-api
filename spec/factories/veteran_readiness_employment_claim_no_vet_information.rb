# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_readiness_employment_claimm_no_vet_information, class: SavedClaim::VeteranReadinessEmploymentClaim do
    form_id { '28-1900' }

    form {
      {
        use_eva: true,
        use_telecounseling: true,
        years_of_education: '4',
        is_moving: false,
        main_phone: '5555555555',
        cell_phone: '3333333333',
        email: 'cohnjesse@gmail.xom',
        privacy_agreement_accepted: true,
        veteran_address: {
          is_military: true,
          country: 'USA',
          street: '2020 Princess Palm',
          street2: 'line 2',
          street3: 'line 3',
          city: 'FPO',
          state: 'AA',
          postal_code: '33928'
        },
        appointment_time_preferences: {
          morning: true,
          mid_day: false,
          afternoon: false,
          other: false
        }
      }.to_json
    }
  end
end
