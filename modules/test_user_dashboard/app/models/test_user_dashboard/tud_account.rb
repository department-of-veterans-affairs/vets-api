# frozen_string_literal: true

module TestUserDashboard
  class TudAccount < ApplicationRecord
    ID_PROVIDERS = %w[id_me dslogon mhv].freeze

    validates :first_name, :last_name, :email, :gender, presence: true

    # uncomment when adding id_provider column information
    # validates :id_provider, presence: true
    # validates :id_provider, inclusion: { in: ID_PROVIDERS }
  end
end
