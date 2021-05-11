# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require_relative 'response'

module FacilitiesApi
  module V1
    module MobileCovid
      class Client < Common::Client::Base
        configuration V1::MobileCovid::Configuration

        def direct_booking_eligibility_criteria_by_id(id)
          response = perform(:get, "/facilities/v1/direct-booking-eligibility-criteria/#{id}", nil)
          V1::MobileCovid::Response.new(response.body, response.status)
        end

      end
    end
  end
end
