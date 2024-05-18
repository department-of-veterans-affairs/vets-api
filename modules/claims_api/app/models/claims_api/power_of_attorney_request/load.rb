# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
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
        PowerOfAttorneyRequest.new(
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
        "#{@data['vetPtcpntID']}_#{@data['procID']}"
      end

      def power_of_attorney_code
        @data['poaCode']
      end

      def authorizes_address_changing
        Utilities.boolean(@data['changeAddressAuth'])
      end

      def authorizes_treatment_disclosure
        Utilities.boolean(@data['healthInfoAuth'])
      end

      def created_at
        Utilities.time(@data['dateRequestReceived'])
      end

      def veteran
        Veteran.new(
          first_name: @data['vetFirstName'],
          middle_name: @data['vetMiddleName'],
          last_name: @data['vetLastName'],
          participant_id: @data['vetPtcpntID']
        )
      end

      def claimant
        # TODO: Check on `claimantRelationship` values in BGS.
        relationship = @data['claimantRelationship']
        return if relationship.blank? || relationship == 'Self'

        Claimant.new(
          first_name: @data['claimantFirstName'],
          last_name: @data['claimantLastName'],
          participant_id: @data['claimantPtcpntID'],
          relationship_to_veteran: relationship
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

      def decision # rubocop:disable Metrics/MethodLength
        status =
          @data['secondaryStatus'].presence_in(
            Decision::Statuses::ALL
          )

        declined_reason =
          if status == Decision::Statuses::DECLINED # rubocop:disable Style/IfUnlessModifier
            @data['declinedReason']
          end

        updated_at = Utilities.time(@data['dateRequestActioned'])

        representative =
          Decision::Representative.new(
            first_name: @data['VSOUserFirstName'],
            last_name: @data['VSOUserLastName'],
            email: @data['VSOUserEmail']
          )

        Decision.new(
          status:,
          declined_reason:,
          representative:,
          updated_at:
        )
      end

      module Utilities
        class << self
          def time(value)
            ActiveSupport::TimeZone['UTC'].parse(value.to_s)
          end

          def boolean(value)
            # `else` => `nil`
            case value
            when 'Y'
              true
            when 'N'
              false
            end
          end
        end
      end
    end
  end
end
