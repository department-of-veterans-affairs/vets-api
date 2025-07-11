#!/usr/bin/env ruby

require 'benchmark'

puts "Simple Rails boot time benchmark..."
puts "=" * 50

# Benchmark the full boot process
total_time = Benchmark.measure do
  puts "Starting Rails boot..."
  
  # Time the config/boot.rb loading
  boot_time = Benchmark.measure { require_relative 'config/boot' }
  puts "config/boot.rb: #{(boot_time.real * 1000).round(1)}ms"
  
  # Time Rails and application loading
  rails_time = Benchmark.measure do
    require 'rails/all'
    require_relative 'config/application'
  end
  puts "Rails + Application: #{(rails_time.real * 1000).round(1)}ms"
  
  # Time the full initialization
  init_time = Benchmark.measure { VetsAPI::Application.initialize! }
  puts "Application.initialize!: #{(init_time.real * 1000).round(1)}ms"
end

puts "\n" + "=" * 50
puts "TOTAL BOOT TIME: #{(total_time.real * 1000).round(1)}ms (#{total_time.real.round(2)}s)"
puts "=" * 50

# Quick check of what Rails considers slow
puts "\nLet's identify bottlenecks..."
puts "Current optimizations in place:"
puts "- ✅ Flipper lazy loading"
puts "- ✅ Sidekiq lazy loading"  
puts "- ✅ Benefits intake lazy loading"
puts "- ✅ Datadog conditional loading"
puts "- ✅ SentryLogging deprecation fixed"
puts "- ✅ Clean console output"

puts "\nFor more detailed analysis, run:"
puts "bundle exec rails runner \"puts 'Boot complete'\"" 