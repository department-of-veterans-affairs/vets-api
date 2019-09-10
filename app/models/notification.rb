# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :account

  validates :subject, :account_id, presence: true
  validates :subject, uniqueness: { scope: :account_id }

  # Creates the ActiveRecord::Enum mappings between the attribute values and
  # their associated database integers.
  #
  # To add a new value, add it to the **end** of the hash, incrementing the integer.
  #
  # Do **NOT** remap any existing attributes or integers.
  #
  # @see https://api.rubyonrails.org/v5.2/classes/ActiveRecord/Enum.html
  #
  ENUM_SUBJECT_VALUE_MAPPINGS = {
    form_10_10ez: 0,
    dashboard_health_care_application_notification: 1
  }.each_key do |subject|
    const_set(subject.upcase, subject)
  end

  # Creates the ActiveRecord::Enum mappings between the attribute values and
  # their associated database integers.
  #
  # To add a new value, add it to the **end** of the hash, incrementing the integer.
  #
  # Do **NOT** remap any existing attributes or integers.
  #
  # @see https://api.rubyonrails.org/v5.2/classes/ActiveRecord/Enum.html
  #
  ENUM_STATUS_VALUE_MAPPINGS = {
    activeduty: 0,
    canceled_declined: 1,
    closed: 2,
    deceased: 3,
    enrolled: 4,
    inelig_champva: 5,
    inelig_character_of_discharge: 6,
    inelig_citizens: 7,
    inelig_filipinoscouts: 8,
    inelig_fugitivefelon: 9,
    inelig_guard_reserve: 10,
    inelig_medicare: 11,
    inelig_not_enough_time: 12,
    inelig_not_verified: 13,
    inelig_other: 14,
    inelig_over65: 15,
    inelig_refusedcopay: 16,
    inelig_training_only: 17,
    login_required: 18,
    none_of_the_above: 19,
    pending_mt: 20,
    pending_other: 21,
    pending_purpleheart: 22,
    pending_unverified: 23,
    rejected_inc_wrongentry: 24,
    rejected_rightentry: 25,
    rejected_sc_wrongentry: 26,
    non_military: 27
  }.each_key do |status|
    const_set(status.upcase, status)
  end

  enum subject: ENUM_SUBJECT_VALUE_MAPPINGS
  enum status: ENUM_STATUS_VALUE_MAPPINGS
end
