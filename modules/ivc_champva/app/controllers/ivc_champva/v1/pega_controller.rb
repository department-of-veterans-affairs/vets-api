# frozen_string_literal: true

module IvcChampva
  module V1
    class PegaController < ApplicationController
      # Skip all default authentication
      skip_before_action :verify_authenticity_token
      skip_after_action :set_csrf_header
      skip_before_action :authenticate

      VALID_KEYS = %w[form_uuid file_names status].freeze

      def update_status
        begin
          data = JSON.parse(params.to_json)

          # Validate JSON structure
          unless data.is_a?(Hash)
            render json: JSON.generate({ status: 500, error: 'Invalid JSON format: Expected a JSON object' })
          end

          if valid_keys?(data)
            # Update DB table
            response = { status: 200 }
          else
            response = { status: 500, error: "Invalid JSON keys" }
          end

          # Convert the response to JSON format
          json_response = JSON.generate(response)

          render json: json_response
        rescue JSON::ParserError => e
          render json: JSON.generate({ status: 500, error: "JSON parsing error: #{e.message}" })
        end
      end

      private

      def valid_keys?(data)
        VALID_KEYS.all? { |key| data.key?(key) }
      end
    end
  end
end