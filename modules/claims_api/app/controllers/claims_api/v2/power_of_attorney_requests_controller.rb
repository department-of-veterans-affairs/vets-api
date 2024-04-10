# frozen_string_literal: true

module ClaimsApi
  module V2
    class PowerOfAttorneyRequestsController < ClaimsApi::V2::ApplicationController
      def index
        render json: {
          data: [
            {
              type: "powerOfAttorneyRequest",
              id: 12345,
              attributes: {
                status: "DECLINED",
                submittedAt: Time.zone.at(1712724672),
                acceptedOrDeclinedAt: Time.zone.at(1712724672),
                declinedReason: "Because I felt like it",
                authorizesAddressChanges: true,
                authorizesTreatmentDisclosures: false,
                powerOfAttorneyCode: "012",
                veteran: {
                  firstName: "Firstus",
                  middleName: nil,
                  lastName: "Lastus"
                },
                claimant: {
                  participantId: 23456,
                  mailingAddress: {
                    city: "Baltimore",
                    state: "MD",
                    zip: "21218",
                    country: "US",
                    militaryPostOffice: nil,
                    militaryPostalCode: nil
                  },
                  nonVeteranIndividual: {
                    firstName: "Alpha",
                    middleName: nil,
                    lastName: "Omega",
                    relationshipToVeteran: "Cousin"
                  }
                },
                representative: {
                  firstName: "Primero",
                  lastName: "Ultimo",
                  email: "primero.ultimo@vsorg.org"
                }
              }
            }
          ]
        }
      end
    end
  end
end
