# frozen_string_literal: true

module DebtManagementCenter
  class DebtStore < Common::RedisStore
    redis_store REDIS_CONFIG[:debt_store][:namespace]
    redis_ttl REDIS_CONFIG[:debt_store][:each_ttl]
    redis_key :uuid

    validates :uuid, presence: true
    validates :debts, presence: true

    attribute :uuid
    attribute :debts

    def get_debt(id)
      debts.find { |d| d['id'] == id }
    end
  end
end
