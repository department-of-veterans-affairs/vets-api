# frozen_string_literal: true

module TestUserDashboard
  class CreateTestUserAccount
    attr_accessor :row

    def initialize(row = {})
      @row = row.to_hash
    end

    def call
      account = Account.create!(idme_uuid: row.delete('idme_uuid'))
      birth_date = Date.parse(row.delete('birth_date')) if row.key?('birth_date')
      test_user_account = TudAccount.create!(row.merge(birth_date: birth_date,
                                                       account_uuid: account.uuid))
      test_user_account.update!(services: test_user_account.profile.services)
      test_user_account
    end
  end
end
