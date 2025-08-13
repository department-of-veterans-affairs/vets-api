#!/usr/bin/env ruby

# Simple script to run uploads controller specs and report coverage
require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  add_filter '/config/'
  track_files "modules/simple_forms_api/app/controllers/simple_forms_api/v1/uploads_controller.rb"
end

system("bundle exec rspec modules/simple_forms_api/spec/requests/simple_forms_api/v1/simple_forms_spec.rb modules/simple_forms_api/spec/requests/simple_forms_api/v1/uploads_controller_comprehensive_coverage_spec.rb --format progress")

puts "\nUploads Controller Coverage Analysis:"
puts "=" * 50

# Check the coverage result
if SimpleCov.result.covered_files.any?
  uploads_controller_file = SimpleCov.result.covered_files.find do |file|
    file.filename.include?("uploads_controller.rb")
  end
  
  if uploads_controller_file
    covered_lines = uploads_controller_file.covered_lines.count
    total_lines = uploads_controller_file.lines_of_code
    coverage_percentage = (covered_lines.to_f / total_lines * 100).round(2)
    
    puts "File: #{uploads_controller_file.filename}"
    puts "Lines of Code: #{total_lines}"
    puts "Covered Lines: #{covered_lines}"
    puts "Coverage: #{coverage_percentage}%"
    
    if coverage_percentage >= 90.0
      puts "✅ PASSED: Coverage is above 90%!"
    else
      puts "❌ FAILED: Coverage is #{coverage_percentage}%, need #{90 - coverage_percentage}% more"
      
      uncovered_lines = uploads_controller_file.missed_lines
      puts "\nUncovered lines:"
      uncovered_lines.each { |line| puts "  Line #{line}" }
    end
  else
    puts "Could not find uploads_controller.rb in coverage results"
  end
else
  puts "No coverage data available"
end
