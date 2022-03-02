# frozen_string_literal: true

module SignIn
  class OAuthSession < ApplicationRecord
    belongs_to :user_account, dependent: nil

    validates :handle, uniqueness: true, presence: true
    validates :hashed_refresh_token, uniqueness: true, presence: true
    validates :refresh_expiration, presence: true
    validates :refresh_creation, presence: true
  end
end
