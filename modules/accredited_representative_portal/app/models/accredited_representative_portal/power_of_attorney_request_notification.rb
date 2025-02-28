# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestNotification < ApplicationRecord
    PERMITTED_TYPES = %w[requested declined expiring expired].freeze
    belongs_to :power_of_attorney_request, class_name: 'PowerOfAttorneyRequest'
    belongs_to :va_notify_notification,
               class_name: 'VANotify::Notification',
               foreign_key: 'notification_id',
               primary_key: 'notification_id',
               optional: true

    validates :notification_type, inclusion: { in: PERMITTED_TYPES }

    scope :requested, -> { where(notification_type: 'requested') }
    scope :declined, -> { where(notification_type: 'declined') }
    scope :expiring, -> { where(notification_type: 'expiring') }
    scope :expired, -> { where(notification_type: 'expired') }

    def status
      va_notify_notification&.status.to_s
    end
  end
end
