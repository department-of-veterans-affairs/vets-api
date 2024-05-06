# frozen_string_literal: true

module IvcChampva
  module V1
    class PegaController < SignIn::ServiceAccountApplicationController
      service_tag 'identity'
      VALID_KEYS = %w[form_uuid file_names status].freeze

      def update_status
        data = JSON.parse(params.to_json)

        # Validate JSON structure
        unless data.is_a?(Hash)
          render json: JSON.generate({ status: 500, error: 'Invalid JSON format: Expected a JSON object' })
        end

        response =
          if valid_keys?(data)
            # Update DB table
            # ...
            # ...
            { status: 200 }
          else
            { status: 500, error: 'Invalid JSON keys' }
          end

        json_response = JSON.generate(response)

        render json: json_response
      rescue JSON::ParserError => e
        render json: JSON.generate({ status: 500, error: "JSON parsing error: #{e.message}" })
      end

      private

      def valid_keys?(data)
        true if VALID_KEYS.all? { |key| data.key?(key) }
      end
    end
  end
end
