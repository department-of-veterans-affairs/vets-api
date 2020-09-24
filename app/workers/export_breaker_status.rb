# frozen_string_literal: true

class ExportBreakerStatus
  include Sidekiq::Worker

  def perform
    Breakers.client.services.each do |service|
      # trying to avoid double-negative with open/closed here, up of 1 is "closed" or "up"
      up = service.latest_outage && !service.latest_outage.ended? ? 0 : 1
      StatsD.gauge("api.external_service.#{service.name}.up", up)
    end
  end
end
