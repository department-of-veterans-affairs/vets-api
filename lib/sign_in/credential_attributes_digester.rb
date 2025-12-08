# frozen_string_literal: true

module SignIn
  class CredentialAttributesDigester
    include ActiveModel::Model
    include ActiveModel::Attributes

    DIGEST_ALGORITHM = 'SHA256'

    attribute :credential_uuid, :string
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :ssn, :string
    attribute :birth_date, :string
    attribute :email, :string

    validates :credential_uuid, :last_name, :birth_date, :email, presence: true
    validate :pepper_present?

    def perform
      validate!

      digest_credential_attributes
    rescue => e
      Rails.logger.info('[SignIn][CredentialAttributesDigester] Failed to digest user attributes',
                        message: e.message)
      nil
    end

    private

    def digest_credential_attributes
      OpenSSL::HMAC.hexdigest(DIGEST_ALGORITHM, pepper, attributes.to_json)
    end

    def pepper
      @pepper ||= IdentitySettings.sign_in.credential_attributes_digester.pepper
    end

    def pepper_present?
      return if pepper.present?

      errors.add(:base, 'Pepper is not configured')
    end
  end
end
