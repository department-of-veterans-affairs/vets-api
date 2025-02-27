# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestNotification < ApplicationRecord
    PERMITTED_TYPES = %w[requested_poa declined_poa expiring_poa expired_poa].freeze
    belongs_to :power_of_attorney_request, class_name: 'PowerOfAttorneyRequest'
    belongs_to :va_notify_notification,
               class_name: 'VANotify::Notification',
               foreign_key: 'notification_id',
               primary_key: 'notification_id',
               optional: true

    validates :notification_type, inclusion: { in: PERMITTED_TYPES }

    scope :requested_poa, -> { where(type: 'requested') }
    scope :declined_poa, -> { where(type: 'declined') }
    scope :expiring_poa, -> { where(type: 'expiring') }
    scope :expired_poa, -> { where(type: 'expired') }

    def status
      va_notify_notification&.status.to_s
    end
  end
end
