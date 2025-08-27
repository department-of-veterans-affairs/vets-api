# frozen_string_literal: true

module MebApi
  module Errors
    class ClaimantNotFoundError < StandardError
      def initialize(msg = 'Claimant not found')
        super
      end
    end
  end
end
