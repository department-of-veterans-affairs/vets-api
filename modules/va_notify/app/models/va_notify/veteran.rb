# frozen_string_literal: true

module VANotify
  class Veteran
    attr_reader :first_name, :user_uuid

    def initialize(first_name:, user_uuid:)
      @first_name = first_name
      @user_uuid = user_uuid
    end

    def icn
      @icn ||= lookup_icn(user_uuid)
    end

    private

    def lookup_icn(user_uuid)
      account = Account.lookup_by_user_uuid(user_uuid) || Account.lookup_by_user_uuid(hyphenate_uuid(user_uuid))
      account&.icn
    end

    # ID.me uuids don’t have hyphens
    # logingov_uuids do have hyphens
    # so we have to check both
    def hyphenate_uuid(user_uuid)
      "#{user_uuid[0, 8]}-#{user_uuid[8, 4]}-#{user_uuid[12, 4]}-#{user_uuid[16, 4]}-#{user_uuid[20, 12]}"
    end
  end
end
