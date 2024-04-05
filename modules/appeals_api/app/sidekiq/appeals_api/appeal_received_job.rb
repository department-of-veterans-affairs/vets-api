# frozen_string_literal: true

require 'sidekiq'
require 'feature_flipper'

module AppealsApi
  class AppealReceivedJob
    include Sidekiq::Job
    STATSD_KEY_PREFIX = 'api.appeals.received'
    STATSD_CLAIMANT_EMAIL_SENT = "#{STATSD_KEY_PREFIX}.claimant.email.sent".freeze

    # rubocop:disable Metrics/MethodLength
    # Sends an email to a veteran or claimant stating that their appeal has been submitted
    # @param [String] appeal_id The id of the appeal record
    # @param [String] appeal_class_str The classname of the appeal as a string
    # @param [String] date_submitted_str The date the appeal was submitted in ISO8601 string format
    def perform(appeal_id, appeal_class_str, date_submitted_str)
      return unless FeatureFlipper.send_email?

      if appeal_id.blank? || appeal_class_str.blank? || date_submitted_str.blank?
        argument_list = [appeal_id, appeal_class_str, date_submitted_str]
        Rails.logger.error("#{self.class.name}: Missing arguments: Received #{argument_list.join(', ')}")
        return
      end

      appeal = appeal_class_str.constantize.find(appeal_id)

      unless appeal.form_data.present? && appeal.auth_headers.present?
        Rails.logger.error("#{self.class.name}: Missing PII for #{appeal_class_str} #{appeal_id}")
        return
      end

      appeal_type_name = appeal.class.name.demodulize.snakecase
      template_name = "#{appeal_type_name}_received#{appeal.non_veteran_claimant? ? '_claimant' : ''}"
      template_id = Settings.vanotify.services.lighthouse.template_id[template_name]

      if template_id.blank?
        Rails.logger.error("#{self.class.name}: could not find VANotify template id for '#{template_name}'")
        return
      end

      date_submitted = DateTime.iso8601(date_submitted_str).strftime('%B %d, %Y')

      if appeal.non_veteran_claimant?
        vanotify_service.send_email(
          {
            email_address: appeal.claimant.email,
            personalisation: {
              date_submitted:,
              first_name: appeal.claimant.first_name,
              veterans_name: appeal.veteran.first_name
            },
            template_id:
          }
        )
      else
        identifier = if appeal.email_identifier[:id_type] == 'email'
                       { email_address: appeal.email_identifier[:id_value] }
                     else
                       { recipient_identifier: appeal.email_identifier }
                     end

        vanotify_service.send_email(
          {
            **identifier,
            personalisation: {
              date_submitted:,
              first_name: appeal.veteran.first_name
            },
            template_id:
          }
        )
      end

      StatsD.increment(STATSD_CLAIMANT_EMAIL_SENT, tags: {
                         appeal_type: appeal.class.name.demodulize.scan(/\p{Upper}/).map(&:downcase).join,
                         claimant_type: appeal.non_veteran_claimant? ? 'non-veteran' : 'veteran'
                       })
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("#{self.class.name}: Unable to find #{appeal_class_str} with id '#{appeal_id}'")
    rescue Date::Error
      Rails.logger.error("#{self.class.name}: Invalid date format: '#{date_submitted_str}' must be in iso8601 format")
    end
    # rubocop:enable Metrics/MethodLength

    def vanotify_service
      @vanotify_service ||= VaNotify::Service.new(Settings.vanotify.services.lighthouse.api_key)
    end
  end
end
