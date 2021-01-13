# frozen_string_literal: true

module TestUserDashboard
  class TudAccount < ApplicationRecord
    belongs_to :account, optional: false
  end
end
