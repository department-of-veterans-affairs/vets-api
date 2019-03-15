# frozen_string_literal: true

class ExternalServicesStatusJob
  include Sidekiq::Worker

  def perform
    ExternalServicesRedis::Status.new.fetch_or_cache
  end
end
