# frozen_string_literal: true

module VANotify
  module NotificationEmail

    CONFIRMATION = :confirmation
    ERROR = :error
    RECEIVED = :received

    class SavedClaim

      def initialize(saved_claim, service_name: nil)
        @claim = saved_claim
        @service_name = service_name
      end

      def send(type, at: nil)
        config = Settings.vanotify.services[service_name]
        config = config&.email[type]
        raise ArgumentError, "Invalid service '#{service_name}' or type '#{type}'" unless config

        return unless flipper?(config.flipper)

        email_template_id = able_to_send?(config.template_id)
        return unless email_template_id

        if at
          VANotify::EmailJob.perform_at(
            at,
            email,
            email_template_id,
            personalization
          )
        else
          VANotify::EmailJob.perform_async(
            email,
            email_template_id,
            personalization
          )
        end

        claim.insert_notification(config.template_id)
      rescue =>
        # TODO add logging and metrics for failure to send
        tags = ["service_name:#{service_name}", "form_id:#{claim.form_id}", "email_template_id:#{email_template_id}"]
        StatsD.increment('', tags:)

        payload = {
          form_id: claim.form_id,
          saved_claim_id: claim.id
          email_template_id:
          message: e&.message
        }
        Rails.logger.error('', **payload)
      end

      private

      attr_reader :claim

      def service_name
        @service_name ||= claim.form_id.downcase.gsub(/-/, '_')
      end

      def flipper?(flipper_id)
        !flipper_id || (flipper_id && Flipper.enabled?(:"#{flipper_id}"))
      end

      def able_to_send?(template_id)
        return if !template_id

        return if email.blank?

        return if claim.va_notification?(config.template_id)

        # TODO add logging and metrics for failure to send
        StatsD.increment('', tags:)
        Rails.logger.warn('', **payload)

        template_id
      end

      def email
        claim.email
      end

      def first_name
        claim.parsed_form.dig('veteranFullName', 'first')
      end

      def personalization
        {
          'first_name' => first_name&.titleize,
          'date_submitted' => claim.submitted_at,
          'confirmation_number' => claim.confirmation_number,
        }
      end

    end
  end
end
