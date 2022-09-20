# frozen_string_literal: true

FactoryBot.define do
  factory :education_career_counseling_claim, class: 'SavedClaim::EducationCareerCounselingClaim' do
    form_id { '28-8832' }

    form {
      {
        claimantAddress: {
          countryName: 'USA',
          addressLine1: '9417 Princess Palm',
          city: 'Tampa',
          stateCode: 'FL',
          zipCode: '33928'
        },
        format: 'json',
        controller: 'v0/education_career_counseling_claims',
        action: 'create',
        status: 'isVeteran',
        claimantInformation: {
          fullName: {
            first: 'Derrick',
            middle: 'J',
            last: 'Lewis'
          },
          ssn: '796104437',
          dateOfBirth: '1950-10-04',
          emailAddress: 'foo@foo.com',
          phoneNumber: '1234567890'
        },
        veteranFullName: {
          first: 'MARK',
          middle: 'WEBB',
          last: 'WEBB'
        },
        veteranSocialSecurityNumber: '796104437'
      }.to_json
    }
  end
end
