# frozen_string_literal: true

module SignIn
  class ServiceAccountConfig < ApplicationRecord
    include SignIn::Concerns::Certifiable

    attribute :access_token_duration, :interval

    validates :service_account_id, presence: true, uniqueness: true
    validates :description, presence: true
    validates :access_token_audience, presence: true
    validates :access_token_duration,
              presence: true,
              inclusion: { in: Constants::ServiceAccountAccessToken::VALIDITY_LENGTHS, allow_nil: false }
    validates :access_token_user_attributes, inclusion: { in: Constants::ServiceAccountAccessToken::USER_ATTRIBUTES }
  end
end
