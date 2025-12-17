# frozen_string_literal: true

require 'va_notify/service'
require 'veteran_facing_services/notification_callback/saved_claim'
require 'veteran_facing_services/notification_email'

module VeteranFacingServices
  module NotificationEmail
    # general SavedClaim email notification function
    #
    # an entry should be in Settings.vanotify.services - config/settings.yml
    # @example
    #     21p_527ez: &vanotify_services_pension
    #       api_key: fake_secret
    #       email:
    #         confirmation:
    #           template_id: form527ez_confirmation_email_template_id
    #           flipper_id: false
    #         error:
    #           template_id: form527ez_error_email_template_id,
    #           flipper_id: form527ez_error_email_flipper_id
    #         received: form527ez_received_email_template_id
    #     pensions: *vanotify_services_pension
    #
    class SavedClaim
      attr_accessor :saved_claim_id

      # @param saved_claim_id [Integer] the claim id for which to send a notification
      # @param service_name [String] alternative serivce name listed in Settings; default is formatted claim.form_id
      def initialize(saved_claim_id = nil, service_name: nil, service_config: nil)
        @saved_claim_id = saved_claim_id
        @vanotify_service = service_name
        @service_config = Config::Options.new(service_config) if service_config
      end

      # deliver a notification for _claim_
      # @see VaNotify::Service
      # @see ClaimVANotification
      #
      # @param email_type [Symbol] one defined in Settings
      # @param saved_claim_id [Integer] the claim id for which to send a notification
      #
      # @return [ClaimVANotification] db record of notification sent
      def deliver(email_type, saved_claim_id = @saved_claim_id, personalization: nil, resend: false)
        @saved_claim_id = saved_claim_id
        @claim = claim_class.find(saved_claim_id) # will raise ActiveRecord::RecordNotFound
        return unless valid_attempt?(email_type, resend:)

        callback_options = { callback_klass:, callback_metadata: }
        notify_client = VaNotify::Service.new(service_config.api_key, callback_options)

        notify_client.send_email(
          {
            email_address: email,
            template_id: email_template_id,
            personalisation: personalization || self.personalization
          }.compact
        )

        monitor.send_success(tags:, context:)
        claim.insert_notification(email_template_id)
      rescue => e
        monitor.send_failure(e&.message, tags:, context:)
      end

      private

      attr_reader :claim, :email_type, :email_template_id

      # return or default the service_name to be used
      def vanotify_service
        @vanotify_service ||= claim&.form_id&.downcase&.gsub(/-/, '_')
      end

      # return the current service config being used
      def service_config
        @service_config ||= Settings.vanotify.services[vanotify_service]
      end

      # flipper exists and is enabled
      # @param flipper_id [String] the flipper id
      def flipper_enabled?(flipper_id)
        !flipper_id || (flipper_id && Flipper.enabled?(:"#{flipper_id}"))
      end

      # check prerequisites before attempting to send the email
      def valid_attempt?(email_type, resend: false)
        raise ArgumentError, "Invalid service_name '#{vanotify_service}'" unless service_config

        @email_type = email_type
        email_config = service_config.email[email_type]
        raise ArgumentError, "Invalid email_type '#{email_type}'" unless email_config

        @email_template_id = email_config.template_id
        raise VeteranFacingServices::NotificationEmail::FailureToSend, 'Invalid template' unless email_template_id
        raise VeteranFacingServices::NotificationEmail::FailureToSend, 'Missing email' if email.blank?

        is_enabled = flipper_enabled?(email_config.flipper_id)
        already_sent = claim.va_notification?(email_config.template_id)
        monitor.duplicate_attempt(tags:, context:) if already_sent && !resend

        email_template_id if is_enabled && (!already_sent || resend)
      end

      # the monitor for _this_ instance
      def monitor
        @monitor ||= VeteranFacingServices::NotificationEmail::Monitor.new
      end

      # monitoring statsd tags
      def tags
        ["service_name:#{vanotify_service}", "form_id:#{claim&.form_id}", "email_type:#{email_type}"]
      end

      # monitoring context
      def context
        callback_metadata
      end

      # OVERRIDES
      # handlers which inherit this class may want to override the below methods

      # the type of SavedClaim to be queried
      def claim_class
        ::SavedClaim
      end

      # retrieve the email from the _claim_
      # - specific claim models should have an `email` method defined
      def email
        claim.try(:email)
      end

      # assemble details for personalization in the email
      def personalization
        {
          'date_submitted' => claim.submitted_at,
          'confirmation_number' => claim.confirmation_number
        }
      end

      # assign the callback class to be used for the notification
      def callback_klass
        VeteranFacingServices::NotificationCallback::SavedClaim.to_s
      end

      # assemble the metadata to be sent with the notification
      def callback_metadata
        {
          form_id: claim&.form_id,
          claim_id: claim&.id,
          saved_claim_id:,
          service_name: vanotify_service,
          email_type:,
          email_template_id:
        }
      end
    end
  end
end
