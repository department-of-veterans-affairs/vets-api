# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestNotification < ApplicationRecord
    self.inheritance_column = nil
    PERMITTED_TYPES = %w[requested declined expiring expired].freeze
    belongs_to :power_of_attorney_request, class_name: 'PowerOfAttorneyRequest'
    belongs_to :va_notify_notification,
               class_name: 'VANotify::Notification',
               foreign_key: 'notification_id',
               primary_key: 'notification_id',
               optional: true

    delegate :accredited_individual, :accredited_organization, to: :power_of_attorney_request

    validates :type, inclusion: { in: PERMITTED_TYPES }

    scope :requested, -> { where(type: 'requested') }
    scope :declined, -> { where(type: 'declined') }
    scope :expiring, -> { where(type: 'expiring') }
    scope :expired, -> { where(type: 'expired') }

    def email_address
      claimant_hash['email']
    end

    def expiration_date
      (base_time + 60.days).strftime('%B %d, %Y')
    end

    def first_name
      claimant_hash['name']['first']
    end

    def last_name
      claimant_hash['name']['last']
    end

    def personalisation
      if %w[declined expiring expired].include?(type)
        {
          'first_name' => first_name
        }
      elsif type == 'requested'
        {
          'first_name' => first_name,
          'last_name' => last_name,
          'submit_date' => submit_date,
          'expiration_date' => expiration_date,
          'representative_name' => representative_name
        }
      end
    end

    def representative_name
      if accredited_individual.present? && accredited_organization.present?
        "#{accredited_individual.full_name.strip} accredited with #{accredited_organization.name.strip}"
      elsif accredited_individual.present?
        accredited_individual.full_name.strip
      else
        accredited_organization.name.strip
      end
    end

    def status
      va_notify_notification&.status.to_s
    end

    def submit_date
      base_time.strftime('%B %d, %Y')
    end

    def template_id
      case type
      when 'requested'
        Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_submit_confirmation_email
      when 'declined'
        Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_submit_decline_email
        # when 'expiring'
        #   Settings.vanotify.services.va_gov.template_id.EXPIRING_TEMPLATE_ID
        # when 'expired'
        #   Settings.vanotify.services.va_gov.template_id.EXPIRED_TEMPLATE_ID
      end
    end

    private

    def base_time
      Time.zone.now.in_time_zone('Eastern Time (US & Canada)')
    end

    def claimant_hash
      @claimant_hash ||= form.parsed_data['dependent'] || form.parsed_data['veteran']
    end

    def form
      @form ||= power_of_attorney_request.power_of_attorney_form
    end
  end
end
