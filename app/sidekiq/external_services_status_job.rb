# frozen_string_literal: true

class ExternalServicesStatusJob
  include Sidekiq::Job

  sidekiq_options(retry: false)

  def perform
    ExternalServicesRedis::Status.new.fetch_or_cache
  end
end
