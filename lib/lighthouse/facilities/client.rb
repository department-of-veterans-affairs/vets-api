# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/facilities/response'

module Lighthouse
  module Facilities
    # Documentation located at:
    # https://developer.va.gov/explore/facilities/docs/facilities
    class Client < Common::Client::Base
      attr_accessor :headers

      configuration Lighthouse::Facilities::Configuration

      def initialize(api_key)
        self.headers = { 'apikey' => api_key }
      end

      def get_by_id(id)
        response = perform(:get, "/va_facilities/v0/facilities/#{id}", nil, headers)
        Lighthouse::Facilities::Response.new(response.body, response.status).new_facility
      end

      def get_facilities(params)
        response = perform(:get, '/va_facilities/v0/facilities', params, headers)
        Lighthouse::Facilities::Response.new(response.body, response.status).get_facilities_list
      end
    end
  end
end
