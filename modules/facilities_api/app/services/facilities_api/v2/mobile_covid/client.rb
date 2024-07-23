# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require_relative 'response'

module FacilitiesApi
  module V2
    module MobileCovid
      class Client < Common::Client::Base
        configuration V2::MobileCovid::Configuration

        def direct_booking_eligibility_criteria_by_id(raw_id)
          id = sanitize_id(raw_id)
          response = perform(:get, "/facilities/v1/direct-booking-eligibility-criteria/#{id}", nil)
          V2::MobileCovid::Response.new(response.body, response.status)
        end

        def sanitize_id(raw_id)
          raw_id[/(.*_)?(\d+.*)/, 2]
        end
      end
    end
  end
end
