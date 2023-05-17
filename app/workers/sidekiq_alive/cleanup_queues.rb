# frozen_string_literal: true

class SidekiqAlive::CleanupQueues
  include Sidekiq::Worker

  def perform
    queues = Sidekiq::Queue.all

    queues.each do |queue|
      next unless queue.name.starts_with? 'sidekiq-alive-'

      registered_queues = SidekiqAlive.registered_instances.map { |i| "sidekiq-alive-#{i.split('::')[1]}" }

      next if registered_queues.include? queue.name

      Rails.logger.debug "Clearing queue #{queue.name}"
      queue.clear
    end
  end
end
