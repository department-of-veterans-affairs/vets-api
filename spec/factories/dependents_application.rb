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
        spouseMarriages: [
          {
            dateOfMarriage: '2015-12-15',
            locationOfMarriage: {
              countryDropdown: 'USA',
              city: 'new york',
              state: 'NY'
            },
            spouseFullName: {
              first: 'spouse',
              last: 'last'
            },
            dateOfSeparation: '2015-12-16',
            locationOfSeparation: {
              countryDropdown: 'USA',
              city: 'new york',
              state: 'NY'
            },
            reasonForSeparation: 'Other',
            explainSeparation: 'other'
          }
        ],
        previousMarriages: [
          {
            dateOfMarriage: '2015-12-15',
            locationOfMarriage: {
              countryDropdown: 'USA',
              city: 'new york',
              state: 'NY'
            },
            spouseFullName: {
              first: 'spouse',
              last: 'last'
            },
            dateOfSeparation: '2015-12-16',
            locationOfSeparation: {
              countryDropdown: 'USA',
              city: 'new york',
              state: 'NY'
            },
            reasonForSeparation: 'Other',
            explainSeparation: 'other'
          }
        ],
        veteranSocialSecurityNumber: '111223333',
        vaFileNumber: '111223333',
        spouseVaFileNumber: '111223333',
        maritalStatus: 'Never Married',
        spouseDateOfBirth: '2016-12-15',
        liveWithSpouse: false,
        spouseAddress: {
          country: 'USA',
          addressType: 'DOMESTIC',
          street: 'street1',
          street2: 'Student Records',
          city: 'LOUISVILLE',
          state: 'KY',
          postalCode: '40292'
        },
        monthlySpousePayment: 1,
        dayPhone: '5551110000',
        nightPhone: '5551110001',
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
            marriedDate: '2016-12-15',
            previouslyMarried: true
          }
        ]
      }.to_json
    )
  end
end
