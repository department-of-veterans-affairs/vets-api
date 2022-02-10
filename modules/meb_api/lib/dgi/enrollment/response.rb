# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Enrollment
      class Response < MebApi::DGI::Response
        attribute :enrollment, Array

        def initialize(response = nil)
          attributes = {
            enrollment: response.body
          }

          super(response.status, attributes)
        end
      end
    end
  end
end
