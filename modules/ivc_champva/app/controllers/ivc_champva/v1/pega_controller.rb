# frozen_string_literal: true

require 'ivc_champva/monitor'

module IvcChampva
  module V1
    class PegaController < SignIn::ServiceAccountApplicationController
      service_tag 'veteran-ivc-champva-forms'
      VALID_KEYS = %w[form_uuid file_names status case_id].freeze

      def update_status
        data = JSON.parse(params.to_json)

        tags = ['service:veteran-ivc-champva-forms', 'function:form submission to Pega']

        unless data.is_a?(Hash)
          # Log the failure due to invalid JSON format
          StatsD.increment('silent_failure_avoided_no_confirmation', tags:)
          render json: JSON.generate({ status: 500, error: 'Invalid JSON format: Expected a JSON object' })
          return
        end

        response =
          if valid_keys?(data)
            update_data(data['form_uuid'], data['file_names'], data['status'], data['case_id'])
          else
            StatsD.increment('silent_failure_avoided_no_confirmation', tags:)
            { json: { error_message: 'Invalid JSON keys' }, status: :bad_request }
          end

        render json: response[:json], status: response[:status]
      rescue JSON::ParserError => e
        # Log the JSON parsing error
        StatsD.increment('silent_failure_avoided_no_confirmation', tags:)
        render json: { error_message: "JSON parsing error: #{e.message}" }, status: :internal_server_error
      end

      private

      def update_data(form_uuid, file_names, status, case_id)
        # First get the query that defines which records we want to update
        ivc_forms = if file_names.any? { |name| name.end_with?('_merged.pdf') }
                      # Use all forms for this UUID if it's a merged PDF case
                      fetch_forms_by_uuid(form_uuid)
                    else
                      # Only use specified files for non-merged cases
                      forms_query(form_uuid, file_names)
                    end

        if ivc_forms.any?
          ivc_forms.update_all(pega_status: status, case_id:) # rubocop:disable Rails/SkipsModelValidations

          # We only need the first form, outside of the file_names field, the data is the same.
          form = ivc_forms.first

          # Possible values for form.pega_status are 'Processed', 'Not Processed'
          send_email(form_uuid, form) if form.email.present? && status == 'Processed'

          monitor.track_update_status(form_uuid, status)

          { json: {}, status: :ok }
        else
          { json:
          { error_message: "No form(s) found with the form_uuid: #{form_uuid} and/or the file_names: #{file_names}." },
            status: :not_found }
        end
      end

      # Temporary rubocop disabling due to feature flag. Will refactor this method
      # once the functionality is demonstrated in staging.
      # rubocop:disable Metrics/MethodLength
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
            created_at: form.created_at.strftime('%B %d, %Y'),
            date_submitted: form.created_at.strftime('%B %d, %Y'),
            form_uuid: form.form_uuid
          }

        if Flipper.enabled?(:champva_vanotify_custom_confirmation_callback, @current_user)
          # Adds custom callback to provide logging when emails are successfully sent
          form_data = form_data.merge(
            { callback_klass: 'IvcChampva::EmailNotificationCallback',
              callback_metadata: {
                statsd_tags: { service: 'veteran-ivc-champva-forms', function: 'IVC CHAMPVA send_email' },
                additional_context: {
                  form_id: form.form_number,
                  form_uuid: form.form_uuid,
                  notification_type: 'confirmation'
                }
              } }
          )
        end

        ActiveRecord::Base.transaction do
          if IvcChampva::Email.new(form_data).send_email
            fetch_forms_by_uuid(form_uuid).update_all(email_sent: true) # rubocop:disable Rails/SkipsModelValidations
          else
            raise ActiveRecord::Rollback, 'Pega Status Update Email send failure'
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

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

      ##
      # retreive a monitor for tracking
      #
      # @return [IvcChampva::Monitor]
      #
      def monitor
        @monitor ||= IvcChampva::Monitor.new
      end
    end
  end
end
