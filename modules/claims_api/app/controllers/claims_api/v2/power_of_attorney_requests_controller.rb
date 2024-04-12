# frozen_string_literal: true

module ClaimsApi
  module V2
    class PowerOfAttorneyRequestsController < ClaimsApi::V2::ApplicationController
      # rubocop:disable Metrics/MethodLength
      def index
        render json: {
          data: [
            {
              type: 'powerOfAttorneyRequest',
              id: 12_345,
              attributes: {
                status: 'DECLINED',
                submittedAt: Time.zone.at(1_712_724_672).iso8601,
                acceptedOrDeclinedAt: Time.zone.at(1_712_724_672).iso8601,
                declinedReason: 'Because I felt like it',
                isAddressChangingAuthorized: true,
                isTreatmentDisclosureAuthorized: false,
                powerOfAttorneyCode: '012',
                veteran: {
                  firstName: 'Firstus',
                  middleName: nil,
                  lastName: 'Lastus'
                },
                claimant: {
                  participantId: 23_456,
                  mailingAddress: {
                    city: 'Baltimore',
                    state: 'MD',
                    zip: '21218',
                    country: 'US',
                    militaryPostOffice: nil,
                    militaryPostalCode: nil
                  },
                  nonVeteranIndividual: {
                    firstName: 'Alpha',
                    middleName: nil,
                    lastName: 'Omega',
                    relationshipToVeteran: 'Cousin'
                  }
                },
                representative: {
                  firstName: 'Primero',
                  lastName: 'Ultimo',
                  email: 'primero.ultimo@vsorg.org'
                }
              }
            }
          ]
        }
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
