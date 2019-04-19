# frozen_string_literal: true

module HCA
  module EnrollmentEligibility
    module ParsedStatuses
      ACTIVEDUTY = 'activeduty'
      CANCELED_DECLINED = 'canceled_declined'
      CLOSED = 'closed'
      DECEASED = 'deceased'
      ENROLLED = 'enrolled'
      INELIG_CHAMPVA = 'inelig_champva'
      INELIG_CHARACTER_OF_DISCHARGE = 'inelig_character_of_discharge'
      INELIG_CITIZENS = 'inelig_citizens'
      INELIG_FILIPINOSCOUTS = 'inelig_filipinoscouts'
      INELIG_FUGITIVEFELON = 'inelig_fugitivefelon'
      INELIG_GUARD_RESERVE = 'inelig_guard_reserve'
      INELIG_MEDICARE = 'inelig_medicare'
      INELIG_NOT_ENOUGH_TIME = 'inelig_not_enough_time'
      INELIG_NOT_VERIFIED = 'inelig_not_verified'
      INELIG_OVER65 = 'inelig_over65'
      INELIG_REFUSEDCOPAY = 'inelig_refusedcopay'
      INELIG_TRAINING_ONLY = 'inelig_training_only'
      INELIG_OTHER = 'inelig_other'
      LOGIN_REQUIRED = 'login_required'
      NONE = 'none_of_the_above'
      PENDING_MT = 'pending_mt'
      PENDING_OTHER = 'pending_other'
      PENDING_PURPLEHEART = 'pending_purpleheart'
      PENDING_UNVERIFIED = 'pending_unverified'
      REJECTED_INC_WRONGENTRY = 'rejected_inc_wrongentry'
      REJECTED_RIGHTENTRY = 'rejected_rightentry'
      REJECTED_SC_WRONGENTRY = 'rejected_sc_wrongentry'

      ELIGIBLE_STATUSES = [
        ACTIVEDUTY,
        CANCELED_DECLINED,
        CLOSED,
        DECEASED,
        ENROLLED,
        INELIG_CHAMPVA,
        INELIG_CHARACTER_OF_DISCHARGE,
        INELIG_CITIZENS,
        INELIG_FILIPINOSCOUTS,
        INELIG_FUGITIVEFELON,
        INELIG_GUARD_RESERVE,
        INELIG_MEDICARE,
        INELIG_NOT_ENOUGH_TIME,
        INELIG_NOT_VERIFIED,
        INELIG_OVER65,
        INELIG_REFUSEDCOPAY,
        INELIG_TRAINING_ONLY,
        INELIG_OTHER,
        LOGIN_REQUIRED,
        NONE,
        PENDING_MT,
        PENDING_OTHER,
        PENDING_PURPLEHEART,
        PENDING_UNVERIFIED,
        REJECTED_INC_WRONGENTRY,
        REJECTED_RIGHTENTRY,
        REJECTED_SC_WRONGENTRY
      ].freeze
    end
  end
end
