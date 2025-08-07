# frozen_string_literal: true

require 'sidekiq'

module EventBusGateway
  class LetterReadyEmailJob
    include Sidekiq::Job
    include SentryLogging

    sidekiq_options retry: 0
    NOTIFY_SETTINGS = Settings.vanotify.services.benefits_management_tools
    HOSTNAME_MAPPING = {
      'dev-api.va.gov' => 'dev.va.gov',
      'staging-api.va.gov' => 'staging.va.gov',
      'api.va.gov' => 'www.va.gov'
    }.freeze

    def perform(participant_id, template_id, ep_code = nil)
      notify_client.send_email(
        recipient_identifier: { id_value: participant_id, id_type: 'PID' },
        template_id:,
        personalisation: { host: HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
                           first_name: get_first_name_from_participant_id(participant_id) }
      )
      
      # Track decision letter emails in Google Analytics
      track_decision_letter_email(ep_code, participant_id) if ep_code
    rescue => e
      record_email_send_failure(e)
    end

    private

    def notify_client
      VaNotify::Service.new(NOTIFY_SETTINGS.api_key,
                            { callback_klass: 'EventBusGateway::VANotifyEmailStatusCallback' })
    end

    def get_first_name_from_participant_id(participant_id)
      bgs = BGS::Services.new(external_uid: participant_id, external_key: participant_id)
      person = bgs.people.find_person_by_ptcpnt_id(participant_id)
      if person
        person[:first_nm].capitalize
      else
        raise StandardError, 'Participant ID cannot be found in BGS'
      end
    end

    def record_email_send_failure(error)
      error_message = 'LetterReadyEmailJob errored'
      ::Rails.logger.error(error_message, { message: error.message })
      StatsD.increment('event_bus_gateway', tags: ['service:event-bus-gateway', "function: #{error_message}"])
    end

    def track_decision_letter_email(ep_code, participant_id)
      return unless Settings.google_analytics.tracking_id.present?
      
      tracker = Staccato.tracker(Settings.google_analytics.tracking_id)
      
      event_params = {
        category: 'email',
        action: 'sent',
        label: "decision_letter_#{ep_code.downcase}",
        non_interactive: true,
        campaign_name: "decision_letter_#{ep_code.downcase}",
        campaign_medium: 'email',
        campaign_source: 'event-bus-gateway',
        document_title: "Decision Letter - #{ep_code}",
        document_path: "/v0/event_bus_gateway/send_email"
      }
      
      # Track in GA
      tracker.event(event_params)
      
      # Track in Datadog for operational monitoring
      StatsD.increment('event_bus_gateway.decision_letter_email.sent', tags: [
        "ep_code:#{ep_code}",
        "service:event-bus-gateway",
        "email_type:decision_letter"
      ])
      
      ::Rails.logger.info('Decision Letter Email Tracked', {
        ep_code: ep_code,
        participant_id: participant_id,
        ga_tracking_id: Settings.google_analytics.tracking_id
      })
    rescue => e
      # Track failures in Datadog
      StatsD.increment('event_bus_gateway.decision_letter_email.tracking_failed', tags: [
        "ep_code:#{ep_code}",
        "service:event-bus-gateway",
        "error_type:#{e.class.name}"
      ])
      
      ::Rails.logger.error('Failed to track decision letter email', {
        ep_code: ep_code,
        participant_id: participant_id,
        error: e.message
      })
    end
  end
end
