class Rx::CoreHealthCheckJob
  sidekiq_options queue: 'critical'

  def perform
    client = Rx::HealthCheckClient.new
    client.check_core
  end
end
