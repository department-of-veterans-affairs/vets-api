# frozen_string_literal: true

module IvcChampva
  module V1
    class PegaController < SignIn::ServiceAccountApplicationController
      service_tag 'veteran-ivc-champva-forms'
      VALID_KEYS = %w[form_uuid file_names status case_id].freeze

      def update_status
        Datadog::Tracing.trace('Start PEGA Status Update') do
          data = JSON.parse(params.to_json)

          tags = ['service:ivc_champva', 'function:form submission to Pega']

          unless data.is_a?(Hash)
            # Log the failure due to invalid JSON format
            StatsD.increment('silent_failure_avoided_no_confirmation', tags: tags)
            render json: JSON.generate({ status: 500, error: 'Invalid JSON format: Expected a JSON object' })
            return
          end

          response =
            if valid_keys?(data)
              update_data(data['form_uuid'], data['file_names'], data['status'], data['case_id'])
            else
              # Log the failure due to invalid keys
              StatsD.increment('silent_failure_avoided_no_confirmation', tags: tags)
              { json: { error_message: 'Invalid JSON keys' }, status: :bad_request }
            end

          render json: response[:json], status: response[:status]
        rescue JSON::ParserError => e
          # Log the JSON parsing error
          StatsD.increment('silent_failure_avoided_no_confirmation', tags: tags)
          render json: { error_message: "JSON parsing error: #{e.message}" }, status: :internal_server_error
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

          # We only need the first form, outside of the file_names field, the data is the same.
          form = ivc_forms.first
          send_email(form_uuid, ivc_forms.first) if form.email.present?

          { json: {}, status: :ok }
        else
          { json:
          { error_message: "No form(s) found with the form_uuid: #{form_uuid} and/or the file_names: #{file_names}." },
            status: :not_found }
        end
      end

      def send_email(form_uuid, form)
        return if form.email_sent

        form_data =
          {
            email: form.email,
            first_name: form.first_name,
            last_name: form.last_name,
            form_number: form.form_number,
            file_count: fetch_forms_by_uuid(form_uuid).where('file_name LIKE ?', '%supporting_doc%').count,
            pega_status: form.pega_status,
            created_at: form.created_at.strftime('%B %d, %Y')
          }

        ActiveRecord::Base.transaction do
          if IvcChampva::Email.new(form_data).send_email
            fetch_forms_by_uuid(form_uuid).update_all(email_sent: true) # rubocop:disable Rails/SkipsModelValidations
          else
            raise ActiveRecord::Rollback, 'Pega Status Update Email send failure'
          end
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

        fetch_forms_by_uuid(form_uuid).merge(file_name_query)
      end

      def fetch_forms_by_uuid(form_uuid)
        @fetch_forms_by_uuid ||= IvcChampvaForm.where(form_uuid:)
      end
    end
  end
end
