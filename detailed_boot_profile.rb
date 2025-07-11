#!/usr/bin/env ruby

require 'benchmark'
require_relative 'config/boot'

puts "Detailed Rails boot time analysis..."
puts "=" * 60

# Profile individual components
components = []

# 1. Rails loading
components << ["Rails framework", Benchmark.measure { require 'rails/all' }]

# 2. Application loading  
components << ["Application config", Benchmark.measure { require_relative 'config/application' }]

# 3. Gem loading (this happens during Bundler.require)
components << ["Gem loading", Benchmark.measure { 
  # This is already done, but let's measure a representative sample
  require 'flipper'
  require 'sidekiq'
  require 'faraday'
}]

# 4. Database connection
components << ["Database connection", Benchmark.measure {
  begin
    ActiveRecord::Base.connection.execute('SELECT 1')
  rescue => e
    puts "DB connection error: #{e.message}"
  end
}]

# 5. Initializers (this is the big one)
puts "\nProfiling initializers..."
puts "-" * 30

initializer_times = []
Dir['config/initializers/*.rb'].sort.each do |file|
  name = File.basename(file, '.rb')
  time = Benchmark.measure do
    begin
      load file
    rescue => e
      puts "Error loading #{name}: #{e.message}"
    end
  end
  
  runtime_ms = (time.real * 1000).round(1)
  initializer_times << [name, runtime_ms]
  
  if runtime_ms > 50 # Only show initializers taking > 50ms
    puts "#{name}: #{runtime_ms}ms"
  end
end

# 6. Full application initialization
puts "\nFull application initialization..."
app_init_time = Benchmark.measure do
  VetsAPI::Application.initialize!
end

puts "\n" + "=" * 60
puts "BOOT TIME BREAKDOWN:"
puts "=" * 60

components.each do |name, time|
  puts "#{name.ljust(20)}: #{(time.real * 1000).round(1)}ms"
end

puts "App initialization".ljust(20) + ": #{(app_init_time.real * 1000).round(1)}ms"

puts "\n" + "=" * 60
puts "SLOWEST INITIALIZERS:"
puts "=" * 60

initializer_times.sort_by { |name, time| -time }.first(10).each do |name, time|
  puts "#{name.ljust(30)}: #{time}ms"
end

puts "\n" + "=" * 60
total_time = components.sum { |_, time| time.real } + app_init_time.real
puts "TOTAL BOOT TIME: #{(total_time * 1000).round(1)}ms (#{total_time.round(2)}s)"