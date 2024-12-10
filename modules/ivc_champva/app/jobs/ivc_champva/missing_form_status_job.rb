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
        if Flipper.enabled?(:champva_failure_email_job_enabled, @current_user)
          # Check if we've been missing Pega status for > custom threshold of days:
          elapsed_days = (current_time - form.created_at).to_i / 1.day
          threshold = Settings.vanotify.services.ivc_champva.failure_email_threshold_days.to_i || 7
          if elapsed_days >= threshold && !form.email_sent
            template_id = "#{form[:form_number]}-FAILURE"
            send_failure_email(form, template_id)
            if Flipper.enabled?(:champva_enhanced_monitor_logging, @current_user)
              additional_context = { form_id: form[:form_number] }
              monitor.log_silent_failure_avoided(additional_context)
              monitor.track_missing_status_email_sent(form[:form_number])
            end
          end
        end

        # Send each form UUID to DataDog
        StatsD.increment('ivc_champva.form_missing_status', tags: ["id:#{form.id}"])
      end
    rescue => e
      Rails.logger.error "IVC Forms MissingFormStatusJob Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    def fetch_forms_by_uuid(form_uuid)
      @fetch_forms_by_uuid ||= IvcChampvaForm.where(form_uuid:)
    end

    def send_failure_email(form, template_id)
      form_data =
        {
          email: form.email,
          first_name: form.first_name,
          last_name: form.last_name,
          form_number: form.form_number,
          file_count: nil,
          pega_status: form.pega_status,
          created_at: form.created_at.strftime('%B %d, %Y'),
          template_id: template_id
        }
      ActiveRecord::Base.transaction do
        if IvcChampva::Email.new(form_data).send_email
          fetch_forms_by_uuid(form[:form_uuid]).update_all(email_sent: true) # rubocop:disable Rails/SkipsModelValidations
        else
          additional_context = { form_id: form[:form_number] }
          monitor.log_silent_failure(additional_context)
          raise ActiveRecord::Rollback, 'Pega Status Update/Action Required Email send failure'
        end
      end
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
