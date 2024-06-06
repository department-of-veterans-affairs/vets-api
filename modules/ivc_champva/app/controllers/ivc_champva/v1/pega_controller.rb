# frozen_string_literal: true

module IvcChampva
  module V1
    class PegaController < SignIn::ServiceAccountApplicationController
      service_tag 'identity'
      VALID_KEYS = %w[form_uuid file_names status case_id].freeze

      def update_status
        Datadog::Tracing.trace('Start PEGA Status Update') do
          data = JSON.parse(params.to_json)

          unless data.is_a?(Hash)
            render json: JSON.generate({ status: 500, error: 'Invalid JSON format: Expected a JSON object' })
          end

          response =
            if valid_keys?(data)
              update_data(data['form_uuid'], data['file_names'], data['status'], data['case_id'])
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

      def update_data(form_uuid, file_names, status, case_id)
        ivc_forms = forms_query(form_uuid, file_names)

        if ivc_forms.any?
          ivc_forms.each do |form|
            form.update!(
              pega_status: status,
              case_id:
            )
          end

          ivc_forms_by_email = ivc_forms.select { |record| record.email.present? }.group_by(&:email)
          send_emails(ivc_forms_by_email) if ivc_forms_by_email.present?

          { status: 200 }
        else
          {
            status: 202,
            error: "No form(s) found with the form_uuid: #{form_uuid} and/or the file_names: #{file_names}."
          }
        end
      end

      def send_emails(ivc_forms_by_email)
        form_data = ivc_forms_by_email.map do |email, forms|
          {
            email:,
            first_name: forms.first.first_name,
            last_name: forms.first.last_name,
            form_number: forms.first.form_number,
            file_names: forms.map(&:file_name),
            pega_status: forms.first.pega_status,
            updated_at: forms.first.updated_at.strftime('%B %d, %Y')
          }
        end

        form_data.each do |data|
          IvcChampva::Email.new(data).send_email
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
