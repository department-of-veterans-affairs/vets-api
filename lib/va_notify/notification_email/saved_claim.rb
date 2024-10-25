# frozen_string_literal: true

require 'va_notify/notification_email'

module VANotify
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
    #         error: null
    #         received: null
    #     pensions: *vanotify_services_pension
    #
    class SavedClaim
      # constructor
      #
      # @param saved_claim [SavedClaim] the claim for which to send a notification
      # @param service_name [String] alternative serivce name listed in Settings
      #   default will be the formatted claim.form_id
      #   @see #vanotify_service
      def initialize(saved_claim, service_name: nil)
        @claim = saved_claim
        @vanotify_service = service_name
      end

      # deliver a notification for _claim_
      # @see VANotify::EmailJob
      # @see ClaimVANotification
      #
      # @param email_type [Symbol] one of VANotify::NotificationEmail::Type and defined in Settings
      # @param at [String|DateTime] valid date string to schedule sending of notification
      #   @see VANotify::EmailJob#perform_at
      #
      # @return [ClaimVANotification] db record of notification sent
      def deliver(email_type, at: nil)
        email_template_id = valid_attempt?(email_type)
        return unless email_template_id

        at ? enqueue_email(email_template_id, at) : send_email(email_template_id)

        db_record = claim.insert_notification(email_template_id)
        tags, context = monitoring(email_type)
        VANotify::NotificationEmail.monitor_deliver_success(tags:, context:)

        db_record
      rescue => e
        tags, context = monitoring(email_type)
        VANotify::NotificationEmail.monitor_send_failure(e&.message, tags:, context:)
      end

      private

      attr_reader :claim, :email_template_id

      # return or default the service_name to be used
      def vanotify_service
        @vanotify_service ||= claim&.form_id&.downcase&.gsub(/-/, '_')
      end

      # flipper exists and is enabled
      # @param flipper_id [String] the flipper id
      def flipper_enabled?(flipper_id)
        !flipper_id || (flipper_id && Flipper.enabled?(:"#{flipper_id}"))
      end

      # check prerequisites before attempting to send the email
      # @param email_type [Symbol] one of VANotify::NotificationEmail::Type and defined in Settings
      def valid_attempt?(email_type)
        config = Settings.vanotify.services[vanotify_service]
        raise ArgumentError, "Invalid service_name '#{vanotify_service}'" unless config

        email_config = config.email[email_type]
        raise ArgumentError, "Invalid email_type '#{email_type}'" unless email_config

        @email_template_id = email_config.template_id
        raise VANotify::NotificationEmail::FailureToSend, 'Invalid template' unless email_template_id
        raise VANotify::NotificationEmail::FailureToSend, 'Missing email' if email.blank?

        is_enabled = flipper_enabled?(email_config.flipper_id)
        already_sent = claim.va_notification?(email_config.template_id)
        if already_sent
          tags, context = monitoring(email_type)
          VANotify::NotificationEmail.monitor_duplicate_attempt(tags:, context:)
        end

        email_template_id if is_enabled && !already_sent
      end

      # create the tags and context for monitoring
      # @param email_type [Symbol] one of VANotify::NotificationEmail::Type and defined in Settings
      def monitoring(email_type)
        tags = ["service_name:#{vanotify_service}",
                "form_id:#{claim.form_id}",
                "email_template_id:#{email_template_id}"]
        context = {
          form_id: claim.form_id,
          saved_claim_id: claim.id,
          service_name: vanotify_service,
          email_type:,
          email_template_id:
        }
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
          personalization
        )
      end

      # send the notification email immediately
      # @see VANotify::EmailJob#perform_async
      # @param email_template_id [String] the template id to be used
      def send_email(email_template_id)
        VANotify::EmailJob.perform_async(
          email,
          email_template_id,
          personalization
        )
      end

      # retrieve the email from the _claim_
      # - specific claim types should have an `email` function defined
      # - or should inherit this class and override this function
      def email
        claim.email
      end

      # assemble details for personalization in the email
      # - specific claim types should inherit this class and override this function
      def personalization
        {
          'date_submitted' => claim.submitted_at,
          'confirmation_number' => claim.confirmation_number
        }
      end
    end
  end
end
