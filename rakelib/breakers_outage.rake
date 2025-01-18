# frozen_string_literal: true

namespace :breakers do
  desc 'List out all breakers-compatible service names'
  task list_services: :environment do
    services = Breakers.client.services.map(&:name)
    puts "Available Services:\n#{services}"
  end

  # e.g. bundle exec rake breakers:begin_forced_outage service=EVSS/Documents
  desc 'Begin a forced outage (requires: service=<service_name>)'
  task begin_forced_outage: :environment do
    services = Breakers.client.services.map(&:name)
    service = ENV.fetch('service', nil)

    raise ArgumentError, "[#{service}] is not a valid service in: #{services}" unless services.include?(ENV['service'])

    Breakers.client.services.select { |s| s.name == service }.first.begin_forced_outage!

    puts "Successfully forced outage of: [#{ENV.fetch('service', nil)}]"
  end

  # e.g. bundle exec rake breakers:end_forced_outage service=EVSS/Documents
  desc 'End a forced outage (requires: service=<service_name>)'
  task end_forced_outage: :environment do
    services = Breakers.client.services.map(&:name)
    service = ENV.fetch('service', nil)

    raise ArgumentError, "[#{service}] is not a valid service in: #{services}" unless services.include?(ENV['service'])

    Breakers.client.services.select { |s| s.name == service }.first.end_forced_outage!

    puts "Successfully ended forced outage of: [#{ENV.fetch('service', nil)}]"
  end
end
