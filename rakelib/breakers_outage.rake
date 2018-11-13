namespace :breakers do

  desc 'List out all breakers-compatible service names'
  task list_services: :environment do
    services = Breakers.client.services.map {|s| s.name }
    puts "Available Services:\n#{services}"
  end

  desc 'Begin a forced outage (requires: service=<service_name>)'
  task begin_forced_outage: :environment do
    services = Breakers.client.services.map {|s| s.name }
    service = ENV['service']

    raise ArgumentError, "[#{service}] is not a valid service in: #{services}" unless services.include?(ENV['service'])

    Breakers.client.services.select{ |s| s.name == service }.first.begin_forced_outage!

    puts "Successfully forced outage of: [#{ENV['service']}]"
  end

  desc 'End a forced outage (requires: service=<service_name>)'
  task end_forced_outage: :environment do
    services = Breakers.client.services.map {|s| s.name }
    service = ENV['service']

    raise ArgumentError, "[#{service}] is not a valid service in: #{services}" unless services.include?(ENV['service'])

    Breakers.client.services.select{ |s| s.name == service }.first.begin_forced_outage!

    puts "Successfully forced outage of: [#{ENV['service']}]"
  end
end