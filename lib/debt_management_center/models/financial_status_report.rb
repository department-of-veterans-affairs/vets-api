# frozen_string_literal: true

module DebtManagementCenter
  class FinancialStatusReport < Common::RedisStore
    redis_store REDIS_CONFIG[:financial_status_report][:namespace]
    redis_ttl REDIS_CONFIG[:financial_status_report][:each_ttl]
    redis_key :uuid

    validates :uuid, presence: true
    validates :filenet_id, presence: true

    attribute :uuid
    attribute :filenet_id
  end
end
