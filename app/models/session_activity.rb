# frozen_string_literal: true

class SessionActivity < ApplicationRecord
  after_initialize :initialize_defaults
  SESSION_ACTIVITY_TYPES = %w[signup mhv dslogon idme logingov mfa verify slo].freeze

  # Initial validations on creation
  validates :originating_request_id, presence: true
  validates :originating_ip_address, presence: true
  validates :name, presence: true, inclusion: { in: SESSION_ACTIVITY_TYPES, allow_blank: true }
  validates :status, presence: true, inclusion: { in: %w[incomplete success fail], allow_blank: true }

  # Additional validations on update
  # TODO: add these later.

  private

  def initialize_defaults
    return if persisted?

    self.status ||= 'incomplete'
  end
end
