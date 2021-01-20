# frozen_string_literal: true

module TestUserDashboard
  class TudAccount < ApplicationRecord
    ID_PROVIDERS = %w(id_me dslogon mhv)

    validates :first_name, :last_name, :email, :gener, :id_provider, presence: true
    validates :id_provider, inclusion: { in: ID_PROVIDERS }

  end
end
