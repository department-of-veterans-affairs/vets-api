# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module SubmitEnrollment
      class Response < MebApi::DGI::Response
        attribute :enrollment_certify_responses, Hash, array: true

        def initialize(response = nil)
          attributes = {
            enrollment_certify_responses: response.body['enrollment_certify_responses']
          }

          super(response.status, attributes)
        end
      end
    end
  end
end
