# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength, Metrics/MethodLength
module Notifications
  module EnumStatusValues
    extend ActiveSupport::Concern

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
    INELIG_OTHER = 'inelig_other'
    INELIG_OVER65 = 'inelig_over65'
    INELIG_REFUSEDCOPAY = 'inelig_refusedcopay'
    INELIG_TRAINING_ONLY = 'inelig_training_only'
    LOGIN_REQUIRED = 'login_required'
    NONE = 'none_of_the_above'
    PENDING_MT = 'pending_mt'
    PENDING_OTHER = 'pending_other'
    PENDING_PURPLEHEART = 'pending_purpleheart'
    PENDING_UNVERIFIED = 'pending_unverified'
    REJECTED_INC_WRONGENTRY = 'rejected_inc_wrongentry'
    REJECTED_RIGHTENTRY = 'rejected_rightentry'
    REJECTED_SC_WRONGENTRY = 'rejected_sc_wrongentry'

    class_methods do
      # Creates the ActiveRecord::Enum mappings between the attribute values and
      # their associated database integers.
      #
      # To add a new value, add it to the **end** of the hash, incrementing the integer.
      #
      # Do **NOT** remap any existing attributes or integers.
      #
      # @return <Hash>
      # @see https://api.rubyonrails.org/v5.2/classes/ActiveRecord/Enum.html
      #
      def statuses_mapped_to_database_integers
        {
          ACTIVEDUTY => 0,
          CANCELED_DECLINED => 1,
          CLOSED => 2,
          DECEASED => 3,
          ENROLLED => 4,
          INELIG_CHAMPVA => 5,
          INELIG_CHARACTER_OF_DISCHARGE => 6,
          INELIG_CITIZENS => 7,
          INELIG_FILIPINOSCOUTS => 8,
          INELIG_FUGITIVEFELON => 9,
          INELIG_GUARD_RESERVE => 10,
          INELIG_MEDICARE => 11,
          INELIG_NOT_ENOUGH_TIME => 12,
          INELIG_NOT_VERIFIED => 13,
          INELIG_OTHER => 14,
          INELIG_OVER65 => 15,
          INELIG_REFUSEDCOPAY => 16,
          INELIG_TRAINING_ONLY => 17,
          LOGIN_REQUIRED => 18,
          NONE => 19,
          PENDING_MT => 20,
          PENDING_OTHER => 21,
          PENDING_PURPLEHEART => 22,
          PENDING_UNVERIFIED => 23,
          REJECTED_INC_WRONGENTRY => 24,
          REJECTED_RIGHTENTRY => 25,
          REJECTED_SC_WRONGENTRY => 26
        }.symbolize_keys
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength, Metrics/MethodLength
