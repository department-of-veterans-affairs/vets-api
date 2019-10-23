# frozen_string_literal: true

require 'common/models/base'

module Facilities
  module PPMS
    class Response < Common::Base
      attribute :body, String
      attribute :status, Integer

      def initialize(body, status)
        self.body = body
        self.status = status
      end

      def self.from_provider_locator(response, params)
        bbox_num = params[:bbox].map { |x| Float(x) }
        response.body.select! do |provider|
          provider['Latitude'] > bbox_num[1] && provider['Latitude'] < bbox_num[3] &&
            provider['Longitude'] > bbox_num[0] && provider['Longitude'] < bbox_num[2]
        end

        response_body = map_provider_list(response.body)
        new(response_body, response.status).get_body
      end

      def new_provider
        Provider.new(body)
      end

      def get_body
        body
      end

      def self.map_provider_list(body)
        body.map do |provider|
          Provider.from_provloc(provider)
        end
      end
    end
  end
end
