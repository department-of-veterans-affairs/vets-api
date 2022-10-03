# frozen_string_literal: true

module SignIn
  class OAuthSession < ApplicationRecord
    belongs_to :user_account, dependent: nil
    belongs_to :user_verification, dependent: nil

    validates :handle, uniqueness: true, presence: true
    validates :hashed_refresh_token, uniqueness: true, presence: true
    validates :refresh_expiration, presence: true
    validates :refresh_creation, presence: true
    validates :client_id, inclusion: { in: Constants::ClientConfig::CLIENT_IDS, allow_nil: false }

    def active?
      refresh_valid? && session_max_valid?
    end

    private

    def refresh_valid?
      Time.zone.now < refresh_expiration
    end

    def session_max_valid?
      Time.zone.now < refresh_creation + Constants::RefreshToken::SESSION_MAX_VALIDITY_LENGTH_DAYS.days
    end
  end
end
