# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Toe
      class Response < MebApi::DGI::Response
        attribute :sponsors, Array

        def initialize(response = nil)
          attributes = {
            sponsors: response.body['sponsors']
          }

          super(response.status, attributes)
        end
      end
    end
  end
end
