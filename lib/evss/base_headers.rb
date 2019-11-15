# frozen_string_literal: true

module EVSS
  class BaseHeaders
    def initialize(user)
      @user = user
    end

    private

    def iso8601_birth_date
      return nil unless @user&.va_profile&.birth_date

      DateTime.parse(@user.va_profile.birth_date).iso8601
    end
  end
end
