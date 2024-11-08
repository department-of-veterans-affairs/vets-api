# frozen_string_literal: true

module AccreditedRepresentativePortal
  # This service is responsible for fetching the details of a power of attorney request
  class PoaRequestDetailsService
    attr_reader :poa_request_details_id

    def initialize(poa_request_details_id)
      # We will lookup based on this id when we hook this service up to active record
      @poa_details_id = poa_request_details_id
    end

    def call
      # This is a placeholder for the actual implementation
      POA_REQUEST_DETAILS_MOCK_DATA
    end

    # first implementation uses mock data, but this will be replaced with a call to the database
    POA_REQUEST_DETAILS_MOCK_DATA = {
      status: 'Pending',
      declinedReason: nil,
      powerOfAttorneyCode: '091',
      submittedAt: '2024-04-30T11:03:17Z',
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
    }.freeze
  end
end
