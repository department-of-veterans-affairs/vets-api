# frozen_string_literal: true

module EVSS
  class BaseHeaders
    def initialize(user)
      # user may be either ClaimsApi::Veteran or User model
      @user = user
    end
  end
end
