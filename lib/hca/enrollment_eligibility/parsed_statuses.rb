# frozen_string_literal: true

module HCA
  module EnrollmentEligibility
    module ParsedStatuses
      # Defines the collection of eligible HCA enrollment statuses.
      #
      # To add a new status, it **must also be added** to the
      # /app/models/notification#status enum values hash.
      #
      ELIGIBLE_STATUSES = [
        Notification::ACTIVEDUTY,
        Notification::CANCELED_DECLINED,
        Notification::CLOSED,
        Notification::DECEASED,
        Notification::ENROLLED,
        Notification::INELIG_CHAMPVA,
        Notification::INELIG_CHARACTER_OF_DISCHARGE,
        Notification::INELIG_CITIZENS,
        Notification::INELIG_FILIPINOSCOUTS,
        Notification::INELIG_FUGITIVEFELON,
        Notification::INELIG_GUARD_RESERVE,
        Notification::INELIG_MEDICARE,
        Notification::INELIG_NOT_ENOUGH_TIME,
        Notification::INELIG_NOT_VERIFIED,
        Notification::INELIG_OTHER,
        Notification::INELIG_OVER65,
        Notification::INELIG_REFUSEDCOPAY,
        Notification::INELIG_TRAINING_ONLY,
        Notification::LOGIN_REQUIRED,
        Notification::NONE_OF_THE_ABOVE,
        Notification::PENDING_MT,
        Notification::PENDING_OTHER,
        Notification::PENDING_PURPLEHEART,
        Notification::PENDING_UNVERIFIED,
        Notification::REJECTED_INC_WRONGENTRY,
        Notification::REJECTED_RIGHTENTRY,
        Notification::REJECTED_SC_WRONGENTRY
      ].freeze
    end
  end
end
