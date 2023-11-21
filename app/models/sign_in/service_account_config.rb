# frozen_string_literal: true

module SignIn
  class ServiceAccountConfig < ApplicationRecord
    attribute :access_token_duration, :interval

    validates :service_account_id, presence: true, uniqueness: true
    validates :description, presence: true
    validates :access_token_audience, presence: true
    validates :access_token_duration,
              presence: true,
              inclusion: { in: Constants::AccessToken::VALIDITY_LENGTHS, allow_nil: false }

    def assertion_public_keys
      @assertion_public_keys ||= certificates.compact.map do |certificate|
        OpenSSL::X509::Certificate.new(certificate).public_key
      end
    end
  end
end
