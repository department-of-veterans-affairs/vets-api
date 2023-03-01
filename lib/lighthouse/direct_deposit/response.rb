# frozen_string_literal: true

require 'common/models/base'
require_relative 'error'
require_relative 'financial_institution'

module Lighthouse
  module DirectDeposit
    class Response < Common::Base
      attribute :body, String
      attribute :status, Integer

      def initialize(status, body)
        super()
        self.status = status
        self.body = parse(body)
      end

      private

      def parse(body)
        case status
        when 200..299 then Lighthouse::DirectDeposit::FinancialInstitution.build_from(body)
        else Lighthouse::DirectDeposit::Error.build_from(status, body)
        end
      end
    end
  end
end
