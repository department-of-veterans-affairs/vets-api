# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class AsyncResponse < Vet360::Response
      attribute :transaction, Vet360::Models::Transaction

      attr_reader :response_body

      def initialize(status, response = nil)
        @response_body = response&.body
        super(
          status,
          transaction: Vet360::Models::Transaction.build_from(@response_body)
        )
      end
    end

    class EmailUpdateResponse < AsyncResponse; end

    class AddressUpdateResponse < AsyncResponse; end
  end
end
