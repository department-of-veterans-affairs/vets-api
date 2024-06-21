# frozen_string_literal: true

module SignIn
  class ValidatedCredential
    include ActiveModel::Validations

    attr_reader(
      :user_verification,
      :credential_email,
      :client_config,
      :user_attributes,
      :device_sso
    )

    validates(
      :user_verification,
      :client_config,
      presence: true
    )

    def initialize(user_verification:,
                   client_config:,
                   credential_email:,
                   user_attributes:,
                   device_sso:)
      @user_verification = user_verification
      @client_config = client_config
      @credential_email = credential_email
      @user_attributes = user_attributes
      @device_sso = device_sso

      validate!
    end

    def persisted?
      false
    end
  end
end
