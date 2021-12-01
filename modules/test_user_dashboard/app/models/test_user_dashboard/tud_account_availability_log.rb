# frozen_string_literal: true

module TestUserDashboard
  class TudAccountAvailabilityLog < ApplicationRecord
    validates :account_uuid, :checkout_time, presence: true
  end
end
