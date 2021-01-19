# frozen_string_literal: true

module TestUserDashboard
  class TudAccount < ApplicationRecord
    attr_accessor :standard, :available, :checkout_time

    belongs_to :account
  end
end
