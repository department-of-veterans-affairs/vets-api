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
        authorize_poa_request

        render json: POA_REQUEST_LIST_MOCK_DATA
      end

      def show
        authorize_poa_request

        render json: POA_REQUEST_ITEM_MOCK_DATA
      end

      private

      # Temporary authorization using OpenStruct with mock data.
      # TODO: Replace with proper model-based authorization in each action:
      #   def show
      #     @poa_request = current_user.poa_requests.find(params[:id])
      #     authorize @poa_request
      #   end
      #
      #   def index
      #     @poa_requests = current_user.poa_requests
      #     authorize @poa_requests
      #   end
      def authorize_poa_request
        # Using OpenStruct to make the mock data behave like an AR model
        poa_request = OpenStruct.new(
          POA_REQUEST_ITEM_MOCK_DATA.merge(
            poa_code: POA_REQUEST_ITEM_MOCK_DATA[:powerOfAttorneyCode]
          )
        )
        authorize poa_request, policy_class: PowerOfAttorneyRequestsPolicy
      end
    end
  end
end
