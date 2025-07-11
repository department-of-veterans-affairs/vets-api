#!/usr/bin/env ruby

require 'benchmark'
require_relative 'config/boot'
require 'rails/all'

puts "Profiling Rails initializers..."
puts "=" * 60

# Load application but don't initialize yet
require_relative 'config/application'

# Get all initializer files
initializer_files = Dir['config/initializers/*.rb'].sort

puts "Found #{initializer_files.count} initializer files"
puts "-" * 60

initializer_times = []

initializer_files.each do |file|
  filename = File.basename(file, '.rb')
  
  time = Benchmark.measure do
    begin
      load file
    rescue => e
      puts "ERROR loading #{filename}: #{e.message}"
    end
  end
  
  runtime_ms = (time.real * 1000).round(1)
  initializer_times << [filename, runtime_ms]
  
  if runtime_ms > 10 # Only show initializers taking > 10ms
    puts "#{filename}: #{runtime_ms}ms"
  end
end

puts "-" * 60
puts "Top 10 slowest initializers:"
puts "-" * 60

initializer_times.sort_by { |name, time| -time }.first(10).each do |name, time|
  puts "#{name}: #{time}ms"
end

puts "\nNow timing full application initialization..."
puts "-" * 60

app_time = Benchmark.measure do
  VetsAPI::Application.initialize!
end

puts "Full application initialization: #{(app_time.real * 1000).round(1)}ms"