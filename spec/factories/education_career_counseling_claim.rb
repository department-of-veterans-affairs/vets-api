# frozen_string_literal: true

FactoryBot.define do
  factory :education_career_counseling_claim, class: 'SavedClaim::EducationCareerCounselingClaim' do
    form_id { '28-8832' }

    form {
      {
        status: 'isVeteran',
        claimantAddress: {
          countryName: 'USA',
          addressLine1: '9417 Princess Palm',
          city: 'Tampa',
          stateCode: 'FL',
          zipCode: '33928'
        },
        ssn: '796104437',
        dateOfBirth: '1950-10-04',
        claimantPhoneNumber: '5555555555',
        claimantEmailAddress: 'cohnjesse@gmail.xom',
        claimantConfirmEmailAddress: 'cohnjesse@gmail.xom',
        format: 'json',
        controller: 'v0/education_career_counseling_claims',
        action: 'create',
        educationCareerCounselingClaim: {
          status: 'isVeteran',
          claimantAddress: {
            countryName: 'USA',
            addressLine1: '9417 Princess Palm',
            city: 'Tampa',
            stateCode: 'FL',
            zipCode: '33928'
          },
          claimantPhoneNumber: '5555555555',
          claimantEmailAddress: 'cohnjesse@gmail.xom',
          claimantConfirmEmailAddress: 'cohnjesse@gmail.xom'
        },
        veteranFullName: {
          first: 'MARK', middle: 'WEBB', last: 'WEBB'
        },
        veteranSocialSecurityNumber: '796104437'
      }.to_json
    }
  end
end
