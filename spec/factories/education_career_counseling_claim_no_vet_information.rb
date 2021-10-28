# frozen_string_literal: true

FactoryBot.define do
  factory :education_career_counseling_claim_no_vet_information, class: 'SavedClaim::EducationCareerCounselingClaim' do
    form_id { '28-8832' }

    form {
      {
        claimantInformation: {
          fullName: {
            first: 'Dardan',
            middle: 'Adam',
            last: 'Testy',
            suffix: 'Jr.'
          },
          ssn: '333224444',
          dateOfBirth: '1964-12-26',
          VAFileNumber: '22334455',
          emailAddress: 'vet123@test.com',
          phoneNumber: '8888675309'
        },
        claimantAddress: {
          country: 'USA',
          addressLine1: '123 Sunshine Blvd',
          addressLine2: 'Apt 1',
          city: 'Miami',
          stateCode: 'FL',
          postalCode: '33928-0808'
        },
        status: 'isVeteran'
      }.to_json
    }
  end
end
