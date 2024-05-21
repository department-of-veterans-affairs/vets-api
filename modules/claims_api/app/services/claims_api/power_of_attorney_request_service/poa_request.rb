# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    # Notice we're not bothering to memoize many of the instance methods which
    # are very small calculations.
    #
    # TODO: Document philosophy around validity of source data?
    # TODO: Do actual conversion elsewhere and just define model here perhaps.
    class PoaRequest
      class << self
        def load(data)
          new(data)
        end
      end

      Veteran =
        Data.define(
          :first_name,
          :middle_name,
          :last_name,
          :participant_id
        )

      Claimant =
        Data.define(
          :first_name,
          :last_name,
          :participant_id,
          :relationship_to_veteran
        )

      Address =
        Data.define(
          :city, :state, :zip, :country,
          :military_post_office,
          :military_postal_code
        )

      class Decision <
        Data.define(
          :status,
          :representative,
          :declined_reason,
          :updated_at
        )

        Representative =
          Data.define(
            :first_name,
            :last_name,
            :email
          )

        module Statuses
          ALL = [
            NEW = 'New',
            PENDING = 'Pending',
            ACCEPTED = 'Accepted',
            DECLINED = 'Declined'
          ].freeze
        end
      end

      def initialize(data)
        @data = data
      end

      def id
        "#{veteran.participant_id}_#{@data['procID']}"
      end

      def created_at
        Utilities.time(@data['dateRequestReceived'])
      end

      def authorizes_address_changing?
        Utilities.boolean(@data['changeAddressAuth'])
      end

      def authorizes_treatment_disclosure?
        Utilities.boolean(@data['healthInfoAuth'])
      end

      def power_of_attorney_code
        @data['poaCode']
      end

      def veteran
        @veteran ||=
          Veteran.new(
            first_name: @data['vetFirstName'],
            middle_name: @data['vetMiddleName'],
            last_name: @data['vetLastName'],
            participant_id: @data['vetPtcpntID']
          )
      end

      def representative
        @representative ||=
          Representative.new(
            first_name: @data['VSOUserFirstName'],
            last_name: @data['VSOUserLastName'],
            email: @data['VSOUserEmail']
          )
      end

      def claimant
        # TODO: Check on `claimantRelationship` values in BGS.
        relationship = @data['claimantRelationship']
        return if relationship.blank? || relationship == 'Self'

        @claimant ||=
          Claimant.new(
            first_name: @data['claimantFirstName'],
            last_name: @data['claimantLastName'],
            participant_id: @data['claimantPtcpntID'],
            relationship_to_veteran: relationship
          )
      end

      def claimant_address
        @claimant_address ||=
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
        @decision ||= begin
          status =
            @data['secondaryStatus'].presence_in(
              Decision::Statuses::ALL
            )

          declined_reason =
            if status == Decision::Statuses::DECLINED # rubocop:disable Style/IfUnlessModifier
              @data['declinedReason']
            end

          representative =
            Decision::Representative.new(
              first_name: @data['VSOUserFirstName'],
              last_name: @data['VSOUserLastName'],
              email: @data['VSOUserEmail']
            )

          updated_at = Utilities.time(@data['dateRequestActioned'])

          Decision.new(
            status:,
            declined_reason:,
            representative:,
            updated_at:
          )
        end
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
