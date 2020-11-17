# frozen_string_literal: true

FactoryBot.define do
  factory :veteran_readiness_employment_claimm_no_vet_information, class: SavedClaim::VeteranReadinessEmploymentClaim do
    form_id { '28-1900' }

    form {
      {
        useEva: true,
        useTelecounseling: true,
        yearsOfEducation: '4',
        isMoving: false,
        mainPhone: '5555555555',
        cellPhone: '3333333333',
        email: 'test@gmail.xom',
        veteranAddress: {
          isMilitary: true,
          country: 'USA',
          street: '2020 Princess Palm',
          street2: 'line 2',
          street3: 'line 3',
          city: 'FPO',
          state: 'AA',
          postalCode: '33928'
        },
        appointmentTimePreferences: {
          morning: true,
          mid_day: false,
          afternoon: false,
          other: false
        }
      }.to_json
    }
  end
end
