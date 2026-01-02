# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Enrollment
      class Response < MebApi::DGI::Response
        attribute :enrollment_verifications, Hash, array: true
        attribute :last_certified_through_date, String
        attribute :payment_on_hold, Bool

        def initialize(response = nil)
          attributes = {
            last_certified_through_date: response.body['last_certified_through_date'],
            payment_on_hold: response.body['payment_on_hold'],
            enrollment_verifications: response.body['enrollment_verifications']
          }

          super(response.status, attributes)
        end
      end
    end
  end
end
