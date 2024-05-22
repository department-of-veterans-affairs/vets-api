# frozen_string_literal: true

module IvcChampva
  module V1
    class PegaController < SignIn::ServiceAccountApplicationController
      service_tag 'identity'
      VALID_KEYS = %w[form_uuid file_names status].freeze

      def update_status
        Datadog::Tracing.trace('Start PEGA Status Update') do
          data = JSON.parse(params.to_json)

          unless data.is_a?(Hash)
            render json: JSON.generate({ status: 500, error: 'Invalid JSON format: Expected a JSON object' })
          end

          response =
            if valid_keys?(data)
              update_data(data['form_uuid'], data['file_names'], data['status'])
            else
              { status: 500, error: 'Invalid JSON keys' }
            end

          json_response = JSON.generate(response)

          render json: json_response
        rescue JSON::ParserError => e
          render json: JSON.generate({ status: 500, error: "JSON parsing error: #{e.message}" })
        end
      end

      private

      def update_data(form_uuid, file_names, status)
        ivc_forms = forms_query(form_uuid, file_names)

        if ivc_forms.any?
          ivc_forms.each do |form|
            form.update!(
              pega_status: status
            )
          end
          { status: 200 }
        else
          {
            status: 202,
            error: "No form(s) found with the form_uuid: #{form_uuid} and/or the file_names: #{file_names}."
          }
        end
      end

      def valid_keys?(data)
        true if VALID_KEYS.all? { |key| data.key?(key) }
      end

      def forms_query(form_uuid, file_names)
        file_name_conditions = file_names.map { |file_name| { file_name: } }
        file_name_query = file_name_conditions.reduce(IvcChampvaForm.none) do |query, condition|
          query.or(IvcChampvaForm.where(condition))
        end

        IvcChampvaForm.where(form_uuid:).merge(file_name_query)
      end
    end
  end
end
