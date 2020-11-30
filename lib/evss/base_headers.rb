# frozen_string_literal: true

module EVSS
  class BaseHeaders
    def initialize(user)
      # user may be either ClaimsApi::Veteran or User model
      @user = user
    end

    private

    def iso8601_birth_date
      birth_date = @user&.va_profile&.birth_date
      birth_date = @user.identity.birth_date if !birth_date && @user.is_a?(User)
      return nil unless birth_date

      DateTime.parse(birth_date).iso8601
    end
  end
end
