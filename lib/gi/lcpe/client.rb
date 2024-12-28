# frozen_string_literal: true

require 'gi/client'
require_relative 'configuration'

module GI
  module LCPE
    class Client < GI::Client
      configuration GI::LCPE::Configuration

      def get_licenses_and_certs_v1(params = {})
        response = perform(:get, 'v1/lcpe/lacs', params)
        gids_response(response)
      end

      def get_license_and_cert_details_v1(params = {})
        enriched_id = params[:id]
        response = perform(:get, "v1/lcpe/lacs/#{enriched_id}", params.except(:id))
      end

      def get_exams_v1(params = {})
        response = perform(:get, "v1/lcpe/exams", params)
        gids_response(response)
      end
    end
  end
end
