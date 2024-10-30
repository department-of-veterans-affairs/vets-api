# frozen_string_literal: true

require 'gi/client'
require_relative 'configuration'

module GI
  module Lce
    class Client < GI::Client
      configuration GI::Lce::Configuration

      def get_lce_search_results_v1(params = {})
        response = perform(:get, 'v1/lce', params)
        gids_response(response)
      end

      def get_certification_details_v1(params = {})
        certification_id = params[:id]
        response = perform(:get, "v1/lce/certifications/#{certification_id}", params.except(:id))
        gids_response(response)
      end

      def get_exam_details_v1(params = {})
        exam_id = params[:id]
        response = perform(:get, "v1/lce/exams/#{exam_id}", params.except(:id))
        gids_response(response)
      end

      def get_license_details_v1(params = {})
        license_id = params[:id]
        response = perform(:get, "v1/lce/licenses/#{license_id}", params.except(:id))
        gids_response(response)
      end

      def get_prep_details_v1(params = {})
        prep_id = params[:id]
        response = perform(:get, "v1/lce/preps/#{prep_id}", params.except(:id))
        gids_response(response)
      end
    end
  end
end
