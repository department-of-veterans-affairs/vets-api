# frozen_string_literal: true

module VANotify
  class Veteran
    attr_reader :first_name, :user_uuid

    def initialize(first_name:, user_uuid:)
      @first_name = first_name
      @user_uuid = user_uuid
    end

    def icn
      @icn ||= Account.lookup_by_user_uuid(user_uuid).icn
    end
  end
end
