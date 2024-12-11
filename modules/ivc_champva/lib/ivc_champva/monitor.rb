# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module IvcChampva
  class Monitor < ::ZeroSilentFailures::Monitor
    STATS_KEY = 'api.ivc_champva_form'

    def initialize
      super('veteran-ivc-champva-forms')
    end

    # form_uuid: string of the uuid included in a form's metadata
    # form_id: string of the form's government ID (e.g., 10-10d)
    def track_insert_form(form_uuid, form_id)
      additional_context = {
        form_uuid:,
        form_id:
      }
      track_request('info', "IVC ChampVA Forms - #{form_id} inserted into database", "#{STATS_KEY}.insert_form",
                    call_location: caller_locations.first, **additional_context)
    end

    # form_uuid: string of the uuid included in a form's metadata
    # status: string of new Pega status being applied to form
    def track_update_status(form_uuid, status)
      additional_context = {
        form_uuid:,
        status:
      }
      track_request('info', "IVC ChampVA Forms - #{form_uuid} status updated to #{status}",
                    "#{STATS_KEY}.update_status",
                    call_location: caller_locations.first, **additional_context)
    end

    # form_id: string of the form's government ID (e.g., 10-10d)
    def track_missing_status_email_sent(form_id)
      additional_context = {
        form_id:
      }
      track_request('info', "IVC ChampVA Forms - #{form_id} missing status failure email sent",
                    "#{STATS_KEY}.form_missing_status_email_sent",
                    call_location: caller_locations.first, **additional_context)
    end

    def track_send_zsf_notification_to_pega(form_uuid, template_id)
      additional_context = {
        form_uuid:,
        template_id:
      }
      track_request('info', "IVC ChampVA Forms - Sent notification to Pega for submission #{form_uuid}",
                    "#{STATS_KEY}.send_zsf_notification_to_pega",
                    call_location: caller_locations.first, **additional_context)
    end

    def track_failed_send_zsf_notification_to_pega(form_uuid, template_id)
      additional_context = {
        form_uuid:,
        template_id:
      }
      track_request('warn', "IVC ChampVA Forms - Failed to send notification to Pega for submission #{form_uuid}",
                    "#{STATS_KEY}.failed_send_zsf_notification_to_pega",
                    call_location: caller_locations.first, **additional_context)
    end
  end
end
