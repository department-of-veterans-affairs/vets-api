# frozen_string_literal: true

module SignIn
  class ValidatedCredential
    include ActiveModel::Validations

    attr_reader(
      :user_verification,
      :credential_email,
      :client_id
    )

    validates(
      :user_verification,
      :client_id,
      presence: true
    )

    def initialize(user_verification:,
                   client_id:,
                   credential_email:)
      @user_verification = user_verification
      @client_id = client_id
      @credential_email = credential_email

      validate!
    end

    def persisted?
      false
    end
  end
end
