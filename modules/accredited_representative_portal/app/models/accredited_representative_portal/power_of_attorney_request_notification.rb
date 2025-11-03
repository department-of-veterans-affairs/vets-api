# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestNotification < ApplicationRecord
    self.inheritance_column = nil
    PERMITTED_TYPES = %w[requested declined expiring expired enqueue_failed submission_failed].freeze

    PERMITTED_RECIPIENTS = %w[claimant representative resolver].freeze

    belongs_to :power_of_attorney_request, class_name: 'PowerOfAttorneyRequest'
    belongs_to :va_notify_notification,
               class_name: 'VANotify::Notification',
               foreign_key: 'notification_id',
               primary_key: 'notification_id',
               optional: true

    enum(:type, PERMITTED_TYPES.index_with { |v| v })

    enum(:recipient_type, PERMITTED_RECIPIENTS.index_with { |v| v })

    delegate :accredited_individual, :accredited_organization, to: :power_of_attorney_request

    validates :type, inclusion: { in: PERMITTED_TYPES }

    def claimant_hash
      @claimant_hash ||= form.parsed_data['dependent'] || form.parsed_data['veteran']
    end

    def email_address
      case recipient_type
      when 'representative'
        representative_email_address
      when 'resolver'
        resolver_email_address
      else
        claimant_hash['email']
      end
    end

    def representative_email_address
      accredited_individual&.email.presence
    end

    def resolver_email_address
      power_of_attorney_request.resolution&.resolving&.accredited_individual&.email.presence
    end

    def status
      va_notify_notification&.status.to_s
    end

    # rubocop:disable Metrics/MethodLength
    def template_id
      static_templates = {
        'requested' => Settings.vanotify.services.va_gov.template_id
                               .appoint_a_representative_digital_submit_confirmation_email,
        'declined' => Settings.vanotify.services.va_gov.template_id
                              .appoint_a_representative_digital_submit_decline_email,
        'expiring' => Settings.vanotify.services.va_gov.template_id
                              .appoint_a_representative_digital_expiration_warning_email,
        'expired' => Settings.vanotify.services.va_gov.template_id
                             .appoint_a_representative_digital_expiration_confirmation_email
      }.freeze

      failure_templates = {
        'claimant' => Settings.vanotify.services.va_gov.template_id
                              .accredited_representative_portal_poa_request_failure_claimant_email,
        'resolver' => Settings.vanotify.services.va_gov.template_id
                              .accredited_representative_portal_poa_request_failure_rep_email
      }.freeze

      if static_templates.key?(type)
        static_templates[type]
      elsif %w[enqueue_failed submission_failed].include?(type)
        failure_templates.fetch(recipient_type) do
          Rails.logger.warn("Missing template for type=#{type} recipient_type=#{recipient_type}")
          nil
        end
      else
        Rails.logger.warn("Unknown notification type=#{type}")
        nil
      end
    end
    # rubocop:enable Metrics/MethodLength

    private

    def form
      @form ||= power_of_attorney_request.power_of_attorney_form
    end
  end
end
