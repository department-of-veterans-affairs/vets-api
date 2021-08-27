# frozen_string_literal: true

module TestUserDashboard
  class CreateTestUserAccount
    attr_accessor :row

    def initialize(row = {})
      @row = row.to_hash
    end

    def call
      account = Account.find_or_create_by(idme_uuid: row.delete('idme_uuid'))
      account_details = row.merge(account_uuid: account.uuid,
                                  birth_date: birth_date,
                                  services: services).compact

      account = TudAccount.find_or_initialize_by(email: row['email'])
      account.update!(account_details)
    end

    def birth_date
      return unless row.key?('birth_date')

      Date.parse(row.delete('birth_date'))
    end

    def services
      return unless row.key?('services')

      row.delete('services').split(',')
    end
  end
end
