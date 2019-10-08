# frozen_string_literal: true

module Vet360
  module AddressValidation
    class CandidateResponse
      def initialize(body)
        @candidate_addresses = body['candidate_addresses'].map do |address_suggestion_hash|
          {
            address: Vet360::Models::Address.build_from_address_suggestion(address_suggestion_hash).to_h.compact,
            address_meta_data: address_suggestion_hash['address_meta_data']
          }
        end
      end

      def to_json
        @candidate_addresses.to_json
      end
    end
  end
end
