# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Summary
      # Deserialization is inherently linked to a particular BGS service action,
      # as it maps from the representation for that action. For now, since only
      # one such mapping is needed, we showcase it in isolation here.
      class Load
        class << self
          def perform(data)
            new(data).perform
          end
        end

        def initialize(data)
          @data = data
        end

        def perform
          Summary.new(
            id:,
            power_of_attorney_code:,
            authorizes_address_changing:,
            authorizes_treatment_disclosure:,
            veteran:,
            claimant:,
            claimant_address:,
            decision:,
            created_at:
          )
        end

        private

        def id
          [
            @data['vetPtcpntID'],
            @data['procID']
          ].join('_')
        end

        def power_of_attorney_code
          @data['poaCode']
        end

        def authorizes_address_changing
          Utilities::Load.boolean(@data['changeAddressAuth'])
        end

        def authorizes_treatment_disclosure
          Utilities::Load.boolean(@data['healthInfoAuth'])
        end

        def created_at
          Utilities::Load.time(@data['dateRequestReceived'])
        end

        def veteran
          Veteran.new(
            first_name: @data['vetFirstName'],
            middle_name: @data['vetMiddleName'],
            last_name: @data['vetLastName']
          )
        end

        def claimant
          # TODO: Check on `claimantRelationship` values in BGS.
          return if @data['claimantRelationship'].blank?
          return if @data['claimantRelationship'] == 'Self'

          Claimant.new(
            first_name: @data['claimantFirstName'],
            last_name: @data['claimantLastName'],
            relationship_to_veteran: @data['claimantRelationship']
          )
        end

        def claimant_address
          Address.new(
            city: @data['claimantCity'],
            state: @data['claimantState'],
            zip: @data['claimantZip'],
            country: @data['claimantCountry'],
            military_post_office: @data['claimantMilitaryPO'],
            military_postal_code: @data['claimantMilitaryPostalCode']
          )
        end

        def decision
          Decision::Load.perform(@data)
        end
      end
    end
  end
end
