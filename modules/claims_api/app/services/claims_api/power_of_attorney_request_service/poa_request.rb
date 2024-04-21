# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    # Notice we're not bothering to memoize many of the instance methods which
    # are very small calculations.
    #
    # TODO: Document philosophy around validity of source data?
    class PoaRequest
      module Statuses
        ALL = [
          NEW = 'New',
          PENDING = 'Pending',
          ACCEPTED = 'Accepted',
          DECLINED = 'Declined'
        ].freeze
      end

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

      Representative =
        Data.define(
          :first_name,
          :last_name,
          :email
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

      def initialize(data)
        @data = data
      end

      def id
        @data['procID'].to_i
      end

      def status
        @data['secondaryStatus'].presence_in(Statuses::ALL)
      end

      def submitted_at
        Utilities.time(@data['dateRequestReceived'])
      end

      def accepted_or_declined_at
        Utilities.time(@data['dateRequestActioned'])
      end

      def declined_reason
        @data['declinedReason'] if status == Statuses::DECLINED
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
            # TODO: Gotta figure out if this is always present or not.
            participant_id: @data['vetPtcpntID']&.to_i
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
        @claimant ||= begin
          # TODO: Check on `claimantRelationship` values in BGS.
          relationship = @data['claimantRelationship']
          if relationship.present? && relationship != 'Self'
            Claimant.new(
              first_name: @data['claimantFirstName'],
              last_name: @data['claimantLastName'],
              participant_id: @data['claimantPtcpntID'].to_i,
              relationship_to_veteran: relationship
            )
          end
        end
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
