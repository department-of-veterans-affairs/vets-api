# frozen_string_literal: true

require 'sidekiq'

# This job grabs all IVC Forms that are missing a status update from the third-party Pega
# Returns a sends stats to DataDog with the form ids
module IvcChampva
  class MissingFormStatusJob
    include Sidekiq::Job
    sidekiq_options retry: 3

    def perform # rubocop:disable Metrics/MethodLength
      return unless Settings.ivc_forms.sidekiq.missing_form_status_job.enabled

      forms = IvcChampvaForm.where(pega_status: nil)

      return unless forms.any?

      # Send the count of forms to DataDog
      StatsD.gauge('ivc_champva.forms_missing_status.count', forms.count)

      current_time = Time.now.utc
      forms.each do |form|
        # Check if we've been missing Pega status for > custom threshold of days:
        elapsed_days = (current_time - form.created_at).to_i / 1.day
        threshold = Settings.vanotify.services.ivc_champva.failure_email_threshold_days.to_i || 7
        if elapsed_days >= threshold && !form.email_sent
          template_id = "#{form[:form_number]}-FAILURE"
          additional_context = { form_id: form[:form_number], form_uuid: form[:form_uuid] }
          unless Flipper.enabled?(:champva_vanotify_custom_callback, @current_user)
            monitor.log_silent_failure_avoided(additional_context)
            monitor.track_missing_status_email_sent(form[:form_number])
          end
          send_failure_email(form, template_id, additional_context)
          send_zsf_notification_to_pega(form, 'PEGA-TEAM-ZSF')
        elsif elapsed_days >= (threshold - 2) && !form.email_sent
          # Give pega 2-day notice if we intend to email a user.
          send_zsf_notification_to_pega(form, 'PEGA-TEAM_MISSING_STATUS')
        end

        # Send each form UUID to DataDog
        StatsD.increment('ivc_champva.form_missing_status', tags: ["id:#{form.id}"])
      end
    rescue => e
      Rails.logger.error "IVC Forms MissingFormStatusJob Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    def construct_email_payload(form, template_id)
      { email: form.email,
        first_name: form.first_name,
        last_name: form.last_name,
        form_number: form.form_number,
        file_count: nil,
        pega_status: form.pega_status,
        date_submitted: form.created_at.strftime('%B %d, %Y'),
        template_id:,
        form_uuid: form.form_uuid }
    end

    # Sends an email to user notifying them of their submission's failure
    #
    # @param form [IvcChampvaForm] form object in question
    # @param template_id [string] key for template to use in `IvcChampva::Email::EMAIL_TEMPLATE_MAP`
    # @param additional_context [hash] contains properties form_id and form_uuid
    #   (e.g.: {form_id: '10-10d', form_uuid: '12345678-1234-5678-1234-567812345678'})
    def send_failure_email(form, template_id, additional_context)
      form_data = construct_email_payload(form, template_id)

      if Flipper.enabled?(:champva_vanotify_custom_callback, @current_user)
        form_data = form_data.merge(
          {
            callback_klass: 'IvcChampva::ZsfEmailNotificationCallback',
            callback_metadata: {
              statsd_tags: { service: 'veteran-ivc-champva-forms', function: 'IVC CHAMPVA send_failure_email' },
              additional_context:
            }
          }
        )
      end

      ActiveRecord::Base.transaction do
        if IvcChampva::Email.new(form_data).send_email
          fetch_forms_by_uuid(form[:form_uuid]).update_all(email_sent: true) # rubocop:disable Rails/SkipsModelValidations
        else
          monitor.log_silent_failure(additional_context)
          raise ActiveRecord::Rollback, 'Pega Status Update/Action Required Email send failure'
        end
      end
    end

    # Fires off a notification email to Pega so they know the communication status of
    # submissions with missing Pega statuses.
    #
    # @param form_data [hash] hash of form details (see `send_failure_email`)
    # @param form [IvcChampvaForm] form object in question
    def send_zsf_notification_to_pega(form, template_id)
      form_data = construct_email_payload(form, template_id)
      form_data = form_data.merge({
                                    email: Settings.vanotify.services.ivc_champva.pega_inbox_address
                                  })
      if IvcChampva::Email.new(form_data).send_email
        monitor.track_send_zsf_notification_to_pega(form_data[:form_uuid], template_id)
      else
        monitor.track_failed_send_zsf_notification_to_pega(form_data[:form_uuid], template_id)
      end
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
