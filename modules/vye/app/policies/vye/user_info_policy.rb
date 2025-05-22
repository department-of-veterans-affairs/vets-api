# frozen_string_literal: true

module Vye
  UserInfoPolicy = Struct.new(:user, :user_info) do
    def create?
      # The controller now checks for nil user_info before calling the policy,
      # but we still need to handle edge cases for the policy tests
      return false if user_info.nil? || user.nil? || user.icn.nil?
      return false if user_info.user_profile.nil?
      return false if user_info.user_profile.icn != user.icn

      true
    end

    alias_method :show?, :create?
  end
end
