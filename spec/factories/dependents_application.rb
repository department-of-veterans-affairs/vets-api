# frozen_string_literal: true

FactoryBot.define do
  factory :dependents_application do
    state('pending')
    form(
      {
        privacyAgreementAccepted: true,
        claimantEmail: 'foo@foo.com',
        spouseIsVeteran: true,
        liveWithSpouse: true,
        monthlySpousePayment: 1,
        remarks: 'remarks',
        dependents: [
          {
            fullName: {
              first: 'Test',
              last: 'User'
            },
            childDateOfBirth: '2016-12-15',
            childInHousehold: true,
            childAddress: {
              country: 'United States',
              street: 'Office of Military and Veteran',
              street2: 'Student Records',
              city: 'LOUISVILLE',
              state: 'KY',
              postalCode: '40292'
            },
            personWhoLivesWithChild: {
              first: 'Test',
              last: 'User'
            },
            childPlaceOfBirth: 'usa',
            childSocialSecurityNumber: '111223333',
            childRelationship: 'biological',
            attendingCollege: true,
            disabled: true,
            married: true,
            previouslyMarried: true
          }
        ]
      }.to_json
    )
  end
end
