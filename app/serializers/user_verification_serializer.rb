# frozen_string_literal: true

class UserVerificationSerializer
  attr_reader :user_verification, :type, :locked, :credential_id

  def initialize(user_verification:)
    @user_verification = user_verification
  end

  def perform
    serialize_response
  end

  private

  def serialize_response
    {
      type: user_verification.credential_type,
      credential_id: user_verification.credential_identifier,
      locked: user_verification.locked
    }
  end
end
