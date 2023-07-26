# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module ContactInfo
      class Response < MebApi::DGI::Response
        attribute :phone, Array
        attribute :email, Array

        def initialize(status, response = nil)
          attributes = {
            phone: response.body['phones'],
            email: response.body['emails']
          }

          super(status, attributes)
        end
      end
    end
  end
end
