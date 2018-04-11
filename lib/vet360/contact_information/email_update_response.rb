# frozen_string_literal: true

require 'vet360/response'
require 'vet360/contact_information/async_response'

module Vet360
  module ContactInformation
    class EmailUpdateResponse < Vet360::ContactInformation::AsyncResponse
      attribute :email, Hash

      def initialize(status, response = nil)
        # @TODO parse and assign the :email data here?
        super
      end

    end
  end
end
