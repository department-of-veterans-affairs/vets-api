# frozen_string_literal: true

require 'accredited_representative_portal/engine'

module AccreditedRepresentativePortal
  DECLINED_POA_REQUEST_MOCK_DATA = {
    "id": 12345,
    "type": "powerOfAttorneyRequest",
    "attributes": {
      "status": "Declined",
      "declinedReason": "Refused to disclose health information",
      "powerOfAttorneyCode": "012",
      "submittedAt": "2024-04-10T04:51:12Z",
      "expiresAt": "2024-11-31T15:20:00Z",
      "acceptedOrDeclinedAt": "2024-04-10T04:51:12Z",
      "isAddressChangingAuthorized": true,
      "isTreatmentDisclosureAuthorized": false,
      "representative": {
        "firstName": "John",
        "lastName": "Smith",
        "email": "john.smith@vsorg.org"
      },
      "claimant": {
        "firstName": "Morgan",
        "lastName": "Fox",
        "participantId": 23456,
        "relationshipToVeteran": "Child"
      },
      "claimantAddress": {
        "city": "Baltimore",
        "state": "MD",
        "zip": "21218",
        "country": "US",
        "militaryPostOffice": nil,
        "militaryPostalCode": nil
      }
    }
  }
  PENDING_POA_REQUEST_MOCK_DATA = {
    id: 12346,
    type: 'powerOfAttorneyRequest',
    attributes: {
      status: 'Pending',
      declinedReason: nil,
      powerOfAttorneyCode: '091',
      submittedAt: '2024-04-30T11:03:17Z',
      expiresAt: '2024-11-30T15:20:00Z',
      acceptedOrDeclinedAt: nil,
      isAddressChangingAuthorized: false,
      isTreatmentDisclosureAuthorized: true,
      veteran: {
        firstName: 'Jon',
        middleName: nil,
        lastName: 'Smith',
        participantId: '6666666666666'
      },
      representative: {
        email: 'j2@example.com',
        firstName: 'Jane',
        lastName: 'Doe'
      },
      claimant: {
        firstName: 'Sam',
        lastName: 'Smith',
        participantId: '777777777777777',
        relationshipToVeteran: 'Child'
      },
      claimantAddress: {
        city: 'Hartford',
        state: 'CT',
        zip: '06107',
        country: 'GU',
        militaryPostOffice: nil,
        militaryPostalCode: nil
      }
    }
  }.freeze

  ACCEPTED_POA_REQUEST_MOCK_DATA = {
    "id": 54321,
    "type": "powerOfAttorneyRequest",
    "attributes": {
      "status": "Accepted",
      "powerOfAttorneyCode": "056",
      "submittedAt": "2024-04-20T09:22:33Z",
      "expiresAt": "2024-12-31T15:20:00Z",
      "acceptedOrDeclinedAt": "2024-10-31T15:20:00Z",
      "isAddressChangingAuthorized": true,
      "isTreatmentDisclosureAuthorized": false,
      "veteran": {
        "firstName": "Bob",
        "middleName": "G",
        "lastName": "Norris",
        "participantId": 800067890
      },
      "representative": {
        "firstName": "Christopher",
        "lastName": "Lee",
        "email": "christopher.lee@vsorg.org"
      },
      "claimant": {
        "firstName": "Gamma",
        "lastName": "Theta",
        "participantId": 34567,
        "relationshipToVeteran": "Child"
      },
      "claimantAddress": {
        "city": "San Francisco",
        "state": "CA",
        "zip": "94102",
        "country": "US",
        "militaryPostOffice": nil,
        "militaryPostalCode": nil
      }
    }
  }

  POA_REQUEST_LIST_MOCK_DATA = [
    PENDING_POA_REQUEST_MOCK_DATA,
    DECLINED_POA_REQUEST_MOCK_DATA,
    ACCEPTED_POA_REQUEST_MOCK_DATA 
  ].freeze
end
