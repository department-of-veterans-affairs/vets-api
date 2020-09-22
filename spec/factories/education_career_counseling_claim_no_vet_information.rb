# frozen_string_literal: true

FactoryBot.define do
  factory :education_career_counseling_claim_no_vet_information, class: SavedClaim::EducationCareerCounselingClaim do
    form_id { '28-8832' }

    form {
      {
        status: 'isVeteran',
        claimant_phone_number: '5555555555',
        claimant_email_address: 'cohnjesse@gmail.xom',
        claimant_address: {
          country_name: 'USA',
          address_line1: '9417 Princess Palm',
          city: 'Tampa',
          state_code: 'FL',
          zip_code: '33928'
        },
        claimantInformation: {
          fullName: {
            first: 'JAIME',
            middle: 'Lee',
            last: 'BROOKS'
          },
          ssn: '796186272',
          dateOfBirth: '1975-11-26'
        }
      }.to_json
    }
  end
end
