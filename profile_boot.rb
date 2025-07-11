#!/usr/bin/env ruby

require 'benchmark'

puts "Profiling Rails boot time..."
puts "=" * 50

total_time = Benchmark.measure do
  puts "Loading boot.rb..."
  boot_time = Benchmark.measure do
    require_relative 'config/boot'
  end
  puts "Boot time: #{boot_time.real.round(2)}s"
  
  puts "\nLoading Rails and gems..."
  rails_time = Benchmark.measure do
    require 'rails/all'
    require_relative 'config/application'
  end
  puts "Rails + gems time: #{rails_time.real.round(2)}s"
  
  puts "\nInitializing application..."
  app_time = Benchmark.measure do
    VetsAPI::Application.initialize!
  end
  puts "Application initialization time: #{app_time.real.round(2)}s"
end

puts "\n" + "=" * 50
puts "Total boot time: #{total_time.real.round(2)}s"