# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestsController < ApplicationController
      POA_REQUEST_ITEM_MOCK_DATA = {
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

      POA_REQUEST_LIST_MOCK_DATA = [
        POA_REQUEST_ITEM_MOCK_DATA,
        POA_REQUEST_ITEM_MOCK_DATA,
        POA_REQUEST_ITEM_MOCK_DATA
      ].freeze

      def index
        render json: POA_REQUEST_LIST_MOCK_DATA
      end

      def show
        render json: POA_REQUEST_ITEM_MOCK_DATA
      end
    end
  end
end
