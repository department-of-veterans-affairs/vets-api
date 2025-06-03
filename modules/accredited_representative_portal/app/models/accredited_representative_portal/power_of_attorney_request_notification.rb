# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestNotification < ApplicationRecord
    self.inheritance_column = nil
    PERMITTED_TYPES = %w[requested declined expiring expired enqueue_failed_claimant enqueue_failed_rep
                         submission_failed_claimant submission_failed_rep].freeze

    belongs_to :power_of_attorney_request, class_name: 'PowerOfAttorneyRequest'
    belongs_to :va_notify_notification,
               class_name: 'VANotify::Notification',
               foreign_key: 'notification_id',
               primary_key: 'notification_id',
               optional: true

    enum type: PERMITTED_TYPES.index_with { |v| v }

    delegate :accredited_individual, :accredited_organization, to: :power_of_attorney_request

    validates :type, inclusion: { in: PERMITTED_TYPES }

    def claimant_hash
      @claimant_hash ||= form.parsed_data['dependent'] || form.parsed_data['veteran']
    end

    def email_address
      claimant_hash['email']
    end

    def accredited_individual_email_address
      if accredited_individual.present? && accredited_individual&.email.present?
        accredited_individual&.email
      else
        raise Common::Exceptions::InternalServerError, 'No representative email address found'
      end
    end

    def status
      va_notify_notification&.status.to_s
    end

    def template_id
      case type
      when 'requested'
        Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_submit_confirmation_email
      when 'declined'
        Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_submit_decline_email
      when 'expiring'
        Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_expiration_warning_email
      when 'expired'
        Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_expiration_confirmation_email
      when 'enqueue_failed_claimant' || 'submission_failed_claimant'
        Settings.vanotify.services.va_gov.template_id
                .accredited_representative_portal_poa_request_failure_claimant_email
      when 'enqueue_failed_rep' || 'submission_failed_rep'
        Settings.vanotify.services.va_gov.template_id
                .accredited_representative_portal_poa_request_failure_rep_email
      end
    end

    private

    def form
      @form ||= power_of_attorney_request.power_of_attorney_form
    end
  end
end
