# frozen_string_literal: true

class SidekiqAlive::CleanupQueues
  include Sidekiq::Worker

  def perform
    # Get all hostnames of Sidekiq processes
    processes = Sidekiq::ProcessSet.new

    vsp_env = Settings.vsp_environment
    current_env = vsp_env == 'development' ? 'dev' : vsp_env
    hostname_suffix = "sidekiq_alive-#{current_env}-api.va.gov"
    if current_env == 'production'
      hostname_suffix = 'sidekiq_alive-api.va.gov' # No env - api.va.gov NOT production-api.va.gov
    end

    # list of Sidekiq hostnames
    hostnames = processes.map { |p| "#{p['hostname']}_#{hostname_suffix}" }

    # Find all Sidekiq Alive queues
    queues = Sidekiq::Queue.all

    queues.each do |queue|
      next unless queue.name.starts_with? 'vets-api-sidekiq'

      unless hostnames.include?(queue.name)
        queue.clear
        Rails.logger.debug "Cleared queue #{queue.name}"
      end
    end
  end
end
