# frozen_string_literal: true

module SignIn
  class ServiceAccountConfig < ApplicationRecord
    validates :service_account_id, presence: true, uniqueness: true
    validates :description, presence: true
    validates :scopes, presence: true
    validates :access_token_audience, presence: true
    validates :access_token_duration, presence: true
    validate :access_token_duration_max_length

    attribute :access_token_duration, :interval

    def access_token_duration_max_length
      return if errors.present?

      validity_length = Constants::ServiceAccountAccessToken::VALIDITY_LENGTH_SHORT_MINUTES
      errors.add(:base, "Access token duration must be <= #{validity_length.in_minutes} minutes") unless
        access_token_duration <= validity_length
    end

    def service_account_assertion_public_keys
      @service_account_assertion_public_keys ||= certificates.compact.map do |certificate|
        OpenSSL::PKey::RSA.new(certificate)
      end
    end
  end
end
