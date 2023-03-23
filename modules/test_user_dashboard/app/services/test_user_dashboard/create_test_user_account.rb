# frozen_string_literal: true

module TestUserDashboard
  class CreateTestUserAccount
    attr_accessor :row

    def initialize(row = {})
      @row = row.to_hash
    end

    def call
      return unless row['idme_uuid'] || row['logingov_uuid']

      account_details = row.merge(account_uuid: id_uuid,
                                  id_types:,
                                  birth_date:,
                                  services:).compact

      account = TudAccount.find_or_initialize_by(email: row['email'])
      account.update!(account_details)
    end

    private

    def id_uuid
      SecureRandom.uuid
    end

    def id_types
      return unless row.key?('id_types')

      row.delete('id_types').split(',')
    end

    def birth_date
      return unless row.key?('birth_date')

      Date.parse(row.delete('birth_date'))
    end

    def services
      return unless row.key?('services')

      if row['services'].nil?
        nil
      else
        row.delete('services').split(',')
      end
    end
  end
end
