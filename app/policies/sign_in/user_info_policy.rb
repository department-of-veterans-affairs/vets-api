# frozen_string_literal: true

module SignIn
  class UserInfoPolicy
    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
    end

    def show?
      user.present? && client_id.in?(IdentitySettings.sign_in.user_info_clients)
    end

    private

    def client_id
      record.client_id
    end
  end
end
