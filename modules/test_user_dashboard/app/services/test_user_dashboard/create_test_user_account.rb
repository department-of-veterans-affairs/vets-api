# frozen_string_literal: true

module TestUserDashboard
  class CreateTestUserAccount
    attr_accessor :row

    def initialize(row = {})
      @row = row.to_hash
    end

    def call
      account = Account.create(idme_uuid: row.delete('idme_uuid'))
      birth_date = Date.parse(row.delete('birth_date')) if row.key?('birth_date')
      services = row.delete('services').split(',')
      TudAccount.create!(row.merge(account_uuid: account.uuid,
                                   birth_date: birth_date,
                                   services: services))
    end
  end
end
