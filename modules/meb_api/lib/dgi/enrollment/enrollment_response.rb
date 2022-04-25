# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Enrollment
      class Response < MebApi::DGI::Response
        attribute :enrollment_verifications, Array

        def initialize(response = nil)
          attributes = {
            enrollment_verifications: response.body['enrollment_verifications']
          }

          super(response.status, attributes)
        end
      end
    end
  end
end
