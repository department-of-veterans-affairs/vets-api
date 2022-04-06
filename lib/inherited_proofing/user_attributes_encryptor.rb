# frozen_string_literal: true

require 'jwe'

module InheritedProofing
  class UserAttributesEncryptor
    attr_reader :user_attributes

    def initialize(user_attributes:)
      @user_attributes = user_attributes
    end

    def perform
      JWE.encrypt(user_attributes.to_json, public_key)
    end

    private

    def public_key
      @public_key ||= OpenSSL::PKey::RSA.new(File.read(Settings.logingov.oauth_public_key))
    end
  end
end
