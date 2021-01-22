# frozen_string_literal: true

module EVSS
  class BaseHeaders
    def initialize(user)
      # user may be either ClaimsApi::Veteran or User model
      @user = user
    end

    private

    def iso8601_birth_date
      return unless @user.birth_date

      DateTime.parse(@user.birth_date).iso8601
    end
  end
end
