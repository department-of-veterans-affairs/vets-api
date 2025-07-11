#!/usr/bin/env ruby

# Analyze which gems can be lazy loaded
puts "Analyzing gems that can be lazy loaded..."
puts "=" * 60

# Categories of gems that are typically good candidates for lazy loading
lazy_candidates = {
  # Development/debugging tools
  development_tools: %w[
    guard-rubocop
    seedbank
    web-console
    brakeman
    bundler-audit
    danger
    awesome_print
    byebug
    debug
    pry-byebug
    yard
  ],
  
  # Testing tools
  testing_tools: %w[
    rspec-rails
    rspec-its
    rspec-retry
    rspec-sidekiq
    rspec-instrumentation-matcher
    factory_bot_rails
    faker
    shoulda-matchers
    vcr
    webmock
    timecop
    super_diff
  ],
  
  # Optional/conditional services
  optional_services: %w[
    aws-sdk-kms
    aws-sdk-s3
    aws-sdk-sns
    datadog
    sentry-ruby
    flipper-ui
    coverband
    slack-notify
    google-api-client
    google-apis-core
    google-protobuf
  ],
  
  # File processing (only needed when processing files)
  file_processing: %w[
    combine_pdf
    hexapdf
    pdf-forms
    pdf-reader
    prawn
    prawn-markup
    prawn-table
    rtesseract
    mini_magick
    fastimage
    carrierwave
    carrierwave-aws
    shrine
  ],
  
  # Background job processing
  background_jobs: %w[
    sidekiq
    rufus-scheduler
  ],
  
  # API clients (only needed when calling specific APIs)
  api_clients: %w[
    octokit
    restforce
    notifications-ruby-client
    govdelivery-tms
    fitbit_api
    fhir_client
  ],
  
  # Parsing/serialization (only needed when parsing specific formats)
  parsing_tools: %w[
    gyoku
    savon
    avro
    csv
    roo
    ox
    nkf
    liquid
  ]
}

puts "GEMS THAT CAN BE LAZY LOADED:"
puts "=" * 60

lazy_candidates.each do |category, gems|
  puts "\n#{category.to_s.upcase.gsub('_', ' ')}:"
  puts "-" * 30
  gems.each { |gem| puts "  - #{gem}" }
end

puts "\n" + "=" * 60
puts "IMPLEMENTATION SUGGESTIONS:"
puts "=" * 60

puts <<~SUGGESTIONS
1. HIGH IMPACT - Optional Services:
   gem 'datadog', require: false
   gem 'sentry-ruby', require: false  
   gem 'aws-sdk-kms', require: false
   gem 'aws-sdk-s3', require: false
   gem 'aws-sdk-sns', require: false
   
2. MEDIUM IMPACT - File Processing:
   gem 'combine_pdf', require: false
   gem 'hexapdf', require: false
   gem 'prawn', require: false
   gem 'mini_magick', require: false
   
3. LOW IMPACT - Background Jobs:
   gem 'sidekiq', require: false (load in initializer)
   
4. VERY LOW IMPACT - API Clients:
   gem 'octokit', require: false
   gem 'restforce', require: false

CAUTION: These gems are likely needed at boot time:
- rails (obviously)
- activerecord-* (database)
- faraday-* (HTTP client)
- flipper (feature flags)
- pundit (authorization)
- config (settings)
SUGGESTIONS

puts "\nTo implement: Add 'require: false' to gems, then require them in:"
puts "- Initializers (for services like Datadog, Sentry)"
puts "- Service classes (for file processing, API clients)"
puts "- Job classes (for background processing)"