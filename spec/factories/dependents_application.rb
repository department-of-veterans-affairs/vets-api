# frozen_string_literal: true

FactoryBot.define do
  factory :dependents_application do
    state { 'pending' }
    user do
      build(:evss_user)
    end

    form {
      {
        privacyAgreementAccepted: true,
        veteranEmail: 'foo@foo.com',
        veteranFullName: {
          first: 'first',
          last: 'last'
        },
        veteranAddress: {
          countryDropdown: 'USA',
          addressType: 'DOMESTIC',
          street: 'street1',
          street2: 'Student Records',
          city: 'LOUISVILLE',
          state: 'KY',
          postalCode: '40292'
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
        currentMarriage: {
          spouseIsVeteran: true,
          spouseDateOfBirth: '2016-12-15',
          liveWithSpouse: false,
          spouseVaFileNumber: '111223333',
          spouseAddress: {
            countryDropdown: 'Country Not In List',
            countryText: 'countryText',
            addressType: 'INTERNATIONAL',
            street: 'street1',
            street2: 'Student Records',
            street3: 'street3',
            city: 'LOUISVILLE'
          },
          spouseSocialSecurityNumber: '111223333'
        },
        marriages: [
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
          },
          {
            dateOfMarriage: '2017-12-15',
            locationOfMarriage: {
              countryDropdown: 'USA',
              city: 'new york',
              state: 'NY'
            },
            spouseFullName: {
              first: 'spouse',
              last: 'last'
            }
          }
        ],
        veteranSocialSecurityNumber: '796043735',
        vaFileNumber: '111223333',
        maritalStatus: 'MARRIED',
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
              countryDropdown: 'USA',
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
    }

    trait :with_response do
      response { '{"submit686Response":{"confirmationNumber":"600142587"}}' }
    end
  end
end
