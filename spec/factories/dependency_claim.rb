# frozen_string_literal: true

FactoryBot.define do
  factory :dependency_claim, class: SavedClaim::DependencyClaim do
    form_id { '21-686C' }

    form {
      {
        privacyAgreementAccepted: true,
        veteranInformation: {
          fullName: {
            first: 'Mark',
            middle: 'A',
            last: 'Webb',
            suffix: 'Jr.'
          },
          ssn: '796104437',
          vaFileNumber: '796104437',
          serviceNumber: '12345678',
          birth_date: '1950-10-04',
        },
        veteranContactInformation: {
          veteranAddress: {
            countryName: 'USA',
            addressLine1: '8200 DOBY LN',
            city: 'PASADENA',
            stateCode: 'CA',
            zipCode: '21122'
          },
          phoneNumber: '1112223333',
          emailAddress: 'vets.gov.user+228@gmail.com'
        }
      }.to_json
    }
  end
end
