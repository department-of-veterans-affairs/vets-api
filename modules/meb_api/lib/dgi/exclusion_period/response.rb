# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module ExclusionPeriod
      class Response < MebApi::DGI::Response
        attribute :exclusion_periods, String, array: true

        def initialize(response = nil)
          attributes = {
            exclusion_periods: response.body['exclusion_periods']
          }

          super(response.status, attributes)
        end
      end
    end
  end
end
