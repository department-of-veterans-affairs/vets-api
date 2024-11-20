# frozen_string_literal: true

module Vye
  UserInfoPolicy = Struct.new(:user, :user_info) do
    def create?
      return true if user_info.present?

      raise Pundit::NotAuthorizedError
    end

    alias_method :show?, :create?

    def access?
      return true if user.present?

      false
    end
  end
end
