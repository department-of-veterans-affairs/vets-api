# frozen_string_literal: true

FactoryBot.define do
  factory :dependents_application do
    state('pending')
    user do
      build(:evss_user)
    end

    form(
      {
        privacyAgreementAccepted: true,
        veteranEmail: 'foo@foo.com',
        spouseIsVeteran: true,
        veteranFullName: {
          first: 'first',
          last: 'last'
        },
        veteranAddress: {
          country: 'USA',
          addressType: 'DOMESTIC',
          street: 'street1',
          street2: 'Student Records',
          city: 'LOUISVILLE',
          state: 'KY',
          postalCode: '40292'
        },
        currentMarriage: {
          dateOfMarriage: '2016-12-15',
          locationOfMarriage: {
            countryDropdown: 'USA',
            city: 'new york',
            state: 'NY'
          },
          spouseFullName: {
            first: 'spouse',
            last: 'last'
          },
          spouseSocialSecurityNumber: '111223333'
        },
        veteranSocialSecurityNumber: '111223333',
        maritalStatus: 'Never Married',
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
              country: 'USA',
              addressType: 'DOMESTIC',
              street: 'street1',
              street2: 'Student Records',
              city: 'LOUISVILLE',
              state: 'KY',
              postalCode: '40292'
            },
            personWhoLivesWithChild: {
              first: 'Test',
              last: 'User'
            },
            childPlaceOfBirth: {
              countryDropdown: 'USA',
              city: 'new york',
              state: 'NY'
            },
            childSocialSecurityNumber: '111223333',
            childRelationship: 'biological',
            attendingCollege: true,
            disabled: true,
            marriedDate: "2016-12-15",
            previouslyMarried: true
          }
        ]
      }.to_json
    )
  end
end
