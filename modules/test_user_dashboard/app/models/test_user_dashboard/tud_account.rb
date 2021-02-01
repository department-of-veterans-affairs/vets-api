# frozen_string_literal: true

module TestUserDashboard
  class TudAccount < ApplicationRecord
    ID_PROVIDERS = %w[id_me dslogon mhv].freeze

    validates :first_name, :last_name, :email, :gender, presence: true

    scope :filter_by_first_name, ->(first_name) { where('first_name like ?', "#{first_name}%") }

    scope :filter_by_last_name, ->(last_name) { where('last_name like ?', "#{last_name}%") }

    scope :filter_by_email, ->(email) { where('email like ?', "#{email}%") }

    scope :filter_by_gender, ->(gender) { where gender: gender }

    scope :filter_by_available, ->(available) { where available: available }

    # uncomment when adding id_provider column information
    # validates :id_provider, presence: true
    # validates :id_provider, inclusion: { in: ID_PROVIDERS }
  end
end
