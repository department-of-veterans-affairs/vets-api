# frozen_string_literal: true

# Script to upload PDF analysis results to AWS S3
# Usage: rails runner lib/disability_compensation/scripts/pdf_analysis/record_to_aws.rb [results_file] [bucket_name] [prefix]

require 'aws-sdk-s3'
require 'logger'

# Initialize logger
logger = Logger.new($stdout)
logger.level = ENV['LOG_LEVEL'] == 'DEBUG' ? Logger::DEBUG : Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
end

results_file = ARGV[0]
bucket_name = ARGV[1] || ENV['AWS_S3_BUCKET'] || 'va-526-pdf-analysis-results'
prefix = ARGV[2] || 'results/'

if results_file.nil?
  logger.error "Usage: rails runner lib/disability_compensation/scripts/pdf_analysis/record_to_aws.rb <results_file> [bucket_name] [prefix]"
  logger.error "Example: rails runner lib/disability_compensation/scripts/pdf_analysis/record_to_aws.rb pdf_check_results_20260209.json"
  logger.info ""
  logger.info "Environment variables:"
  logger.info "  AWS_S3_BUCKET - Default S3 bucket name"
  logger.info "  AWS_ACCESS_KEY_ID - AWS access key"
  logger.info "  AWS_SECRET_ACCESS_KEY - AWS secret key"
  logger.info "  AWS_REGION - AWS region (default: us-gov-west-1)"
  exit 1
end

unless File.exist?(results_file)
  logger.error "ERROR: Results file not found: #{results_file}"
  exit 1
end

# Configure AWS
Aws.config.update(
  region: ENV['AWS_REGION'] || 'us-gov-west-1',
  credentials: Aws::Credentials.new(
    ENV['AWS_ACCESS_KEY_ID'],
    ENV['AWS_SECRET_ACCESS_KEY']
  )
)

s3 = Aws::S3::Client.new

# Generate S3 key
timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
filename = File.basename(results_file)
s3_key = "#{prefix}#{timestamp}_#{filename}"

logger.info "Uploading #{results_file} to s3://#{bucket_name}/#{s3_key}"

begin
  # Upload file to S3
  File.open(results_file, 'rb') do |file|
    s3.put_object(
      bucket: bucket_name,
      key: s3_key,
      body: file,
      content_type: 'application/json',
      metadata: {
        'uploaded_at' => Time.now.iso8601,
        'original_filename' => filename,
        'source' => 'va-526-pdf-analysis'
      }
    )
  end

  logger.info "Successfully uploaded to: s3://#{bucket_name}/#{s3_key}"

  # Generate presigned URL for verification (optional)
  if ENV['GENERATE_PRESIGNED_URL']
    presigner = Aws::S3::Presigner.new
    presigned_url = presigner.presigned_url(
      :get_object,
      bucket: bucket_name,
      key: s3_key,
      expires_in: 3600 # 1 hour
    )
    logger.info "Presigned URL (expires in 1 hour): #{presigned_url}"
  end

rescue Aws::S3::Errors::ServiceError => e
  logger.error "AWS S3 Error: #{e.class} - #{e.message}"
  exit 1
rescue StandardError => e
  logger.error "Error: #{e.class} - #{e.message}"
  exit 1
end

logger.info "Upload complete!"