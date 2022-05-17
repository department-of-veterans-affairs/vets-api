# frozen_string_literal: true

module SignIn
  class ValidatedCredential
    include ActiveModel::Validations

    attr_reader(
      :user_verification,
      :credential_email
    )

    validates(
      :user_verification,
      presence: true
    )

    def initialize(user_verification:,
                   credential_email:)
      @user_verification = user_verification
      @credential_email = credential_email

      validate!
    end

    def persisted?
      false
    end
  end
end
