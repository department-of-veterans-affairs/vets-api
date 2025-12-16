# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Eligibility
      class EligibilityResponse < MebApi::DGI::Response
        attribute :eligibility, Hash, array: true

        def initialize(status, response = nil)
          attributes = {
            eligibility: response.body
          }

          super(status, attributes)
        end
      end
    end
  end
end
