# frozen_string_literal: true

module TestUserDashboard
  class TudAccountAvailabilityLog < ApplicationRecord
    validates :user_account_id, :checkout_time, presence: true
  end
end
