# frozen_string_literal: true

module Vye
  UserInfoPolicy = Struct.new(:user, :user_info) do
    def create?
      return true if user_info.present?

      raise Pundit::NotAuthorizedError
    end

    alias_method :show?, :create?

    def claimant_lookup?
      return true if user.present?

      false
    end

    def claimant_status?
      return true if user.present?

      false
    end

    def verify_claimant?
      return true if user.present?

      false
    end

    def verification_record?
      return true if user.present?

      false
    end
  end
end
