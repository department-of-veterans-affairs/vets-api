#!/usr/bin/env ruby

require 'benchmark'
require_relative 'config/boot'
require 'rails/all'
require_relative 'config/application'

puts "Profiling Rails initialization components..."
puts "=" * 60

# Track initialization events
init_times = {}

# Subscribe to Rails initialization events
ActiveSupport::Notifications.subscribe(/\.active_record$/) do |name, start, finish, id, payload|
  duration = ((finish - start) * 1000).round(1)
  init_times[name] = duration if duration > 10
end

ActiveSupport::Notifications.subscribe(/\.action_controller$/) do |name, start, finish, id, payload|
  duration = ((finish - start) * 1000).round(1)
  init_times[name] = duration if duration > 10
end

ActiveSupport::Notifications.subscribe(/initialize/) do |name, start, finish, id, payload|
  duration = ((finish - start) * 1000).round(1)
  init_times[name] = duration if duration > 10
end

puts "Now initializing Rails application..."
puts "-" * 30

total_time = Benchmark.measure do
  VetsAPI::Application.initialize!
end

puts "\nComponents that took > 10ms:"
puts "-" * 30

init_times.sort_by { |name, time| -time }.each do |name, time|
  puts "#{name}: #{time}ms"
end

puts "\nTotal initialization time: #{(total_time.real * 1000).round(1)}ms"