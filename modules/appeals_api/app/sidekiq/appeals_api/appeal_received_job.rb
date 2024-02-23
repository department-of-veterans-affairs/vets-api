# frozen_string_literal: true

require 'sidekiq'
require 'feature_flipper'

module AppealsApi
  class AppealReceivedJob
    include Sidekiq::Job
    STATSD_KEY_PREFIX = 'api.appeals.received'
    STATSD_CLAIMANT_EMAIL_SENT = "#{STATSD_KEY_PREFIX}.claimant.email.sent".freeze

    # Sends an email to a veteran or claimant stating that their appeal has been submitted
    # @param [String] appeal_id The id of the appeal record
    # @param [String] appeal_class_str The classname of the appeal as a string
    # @param [String] date_submitted_str The date the appeal was submitted in ISO8601 string format
    def perform(appeal_id, appeal_class_str, date_submitted_str)
      return unless FeatureFlipper.send_email?

      if appeal_id.blank? || appeal_class_str.blank? || date_submitted_str.blank?
        argument_list = [appeal_id, appeal_class_str, date_submitted_str]
        raise "Missing arguments in #{self.class.name}: Received #{argument_list.join(', ')}"
      end

      appeal = appeal_class_str.constantize.find(appeal_id)

      unless appeal.form_data.present? && appeal.auth_headers.present?
        raise "Missing PII for #{appeal_class_str} #{appeal_id}"
      end

      vanotify_service.send_email(vanotify_args(appeal, date_submitted_str))

      StatsD.increment(STATSD_CLAIMANT_EMAIL_SENT,
                       tags: {
                         appeal_type: appeal.class.name.demodulize.scan(/\p{Upper}/).map(&:downcase).join,
                         claimant_type: appeal.claimant.signing_appellant? ? 'non-veteran' : 'veteran'
                       })
    end

    def vanotify_args(appeal, date_submitted_str)
      common_info = {
        template_id: appeal_template_id(appeal),
        date_submitted: DateTime.iso8601(date_submitted_str).strftime('%B %d, %Y')
      }

      if appeal.claimant.signing_appellant?
        {
          **common_info,
          email_address: appeal.claimant.email,
          personalisation: { first_name: appeal.claimant.first_name, veterans_name: appeal.veteran.first_name }
        }
      else
        contact_info = if appeal.email_identifier[:id_type] == 'email'
                         { email_address: appeal.email_identifier[:id_value] }
                       else
                         { recipient_identifier: appeal.email_identifier }
                       end

        { **common_info, **contact_info, personalisation: { first_name: appeal.veteran.first_name } }
      end
    rescue Date::Error
      raise "Invalid date format for #{self.class.name}: '#{date_submitted_str}' must be in iso8601 format"
    end

    def appeal_template_id(appeal)
      appeal_type_name = appeal.class.name.demodulize.underscore
      template_name = "#{appeal_type_name}_received#{appeal.claimant.signing_appellant? ? '_claimant' : ''}"
      template_id = Settings.vanotify.services.lighthouse.template_id[template_name]
      raise "#{self.class.name}: could not find VANotify template id for '#{template_name}'" if template_id.blank?

      template_id
    end

    def vanotify_service
      @vanotify_service ||= VaNotify::Service.new(Settings.vanotify.services.lighthouse.api_key)
    end
  end
end
