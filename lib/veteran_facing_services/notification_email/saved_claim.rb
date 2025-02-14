# frozen_string_literal: true

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
      # constructor
      #
      # @param saved_claim [SavedClaim] the claim for which to send a notification
      # @param service_name [String] alternative serivce name listed in Settings
      #   default will be the formatted claim.form_id
      #   @see #vanotify_service
      def initialize(saved_claim_id, service_name: nil)
        @claim = claim_class.find(saved_claim_id)
        @vanotify_service = service_name
      end

      # deliver a notification for _claim_
      # @see VANotify::EmailJob
      # @see ClaimVANotification
      #
      # @param email_type [Symbol] one defined in Settings
      # @param at [String|DateTime] valid date string to schedule sending of notification
      #   @see VANotify::EmailJob#perform_at
      #
      # @return [ClaimVANotification] db record of notification sent
      def deliver(email_type, at: nil)
        @email_type = email_type
        @email_template_id = valid_attempt?
        return unless email_template_id

        at ? enqueue_email(email_template_id, at) : send_email(email_template_id)

        db_record = claim.insert_notification(email_template_id)
        tags, context = for_monitoring
        VeteranFacingServices::NotificationEmail.monitor_deliver_success(tags:, context:)

        db_record
      rescue => e
        tags, context = for_monitoring
        VeteranFacingServices::NotificationEmail.monitor_send_failure(e&.message, tags:, context:)
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
      def valid_attempt?
        raise ArgumentError, "Invalid service_name '#{vanotify_service}'" unless service_config

        email_config = service_config.email[email_type]
        raise ArgumentError, "Invalid email_type '#{email_type}'" unless email_config

        @email_template_id = email_config.template_id
        raise VeteranFacingServices::NotificationEmail::FailureToSend, 'Invalid template' unless email_template_id
        raise VeteranFacingServices::NotificationEmail::FailureToSend, 'Missing email' if email.blank?

        is_enabled = flipper_enabled?(email_config.flipper_id)
        already_sent = claim.va_notification?(email_config.template_id)
        if already_sent
          tags, context = for_monitoring
          VeteranFacingServices::NotificationEmail.monitor_duplicate_attempt(tags:, context:)
        end

        email_template_id if is_enabled && !already_sent
      end

      # create the tags and context for monitoring
      def for_monitoring
        tags = ["service_name:#{vanotify_service}",
                "form_id:#{claim.form_id}",
                "email_template_id:#{email_template_id}"]
        context = callback_metadata

        [tags, context]
      end

      # schedule sending of email at future date
      # @see VANotify::EmailJob#perform_at
      # @param email_template_id [String] the template id to be used
      # @param at [String|DateTime] valid date string to schedule sending of notification
      def enqueue_email(email_template_id, at)
        VANotify::EmailJob.perform_at(
          at,
          email,
          email_template_id,
          personalization,
          service_config.api_key,
          { callback_klass:, callback_metadata: }
        )
      end

      # send the notification email immediately
      # @see VANotify::EmailJob#perform_async
      # @param email_template_id [String] the template id to be used
      def send_email(email_template_id)
        VANotify::EmailJob.perform_async(
          email,
          email_template_id,
          personalization,
          service_config.api_key,
          { callback_klass:, callback_metadata: }
        )
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
        claim.email
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
          form_id: claim.form_id,
          saved_claim_id: claim.id,
          service_name: vanotify_service,
          email_type:,
          email_template_id:
        }
      end
    end
  end
end
