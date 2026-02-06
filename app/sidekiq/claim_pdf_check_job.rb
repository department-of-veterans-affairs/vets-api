# frozen_string_literal: true

require 'aws-sdk-s3'
require 'optparse'
require 'yaml'

class ClaimPdfCheckJob
  # Include Sidekiq::Job only if Sidekiq is available (for job queue usage)
  include Sidekiq::Job if defined?(Sidekiq::Job)

  def perform(start_date = nil, end_date = nil, output_dir = nil, upload_enabled = nil, s3_bucket = nil, s3_region = 'us-gov-west-1', s3_prefix = 'form526-pdf-checks/')
    # Set defaults if not provided
    # TODO: Issue #131101 - Add back proper date defaults
    # start_date ||= (Date.today - 7).to_s
    # end_date ||= Date.today.to_s
    start_date ||= '2024-08-19'  # Issue #131101 placeholder
    end_date ||= '2025-01-10'    # Issue #131101 placeholder
    upload_enabled = true if upload_enabled.nil? # Default to true for upload_enabled

    start_date = Date.parse(start_date)
    end_date = Date.parse(end_date)
    output_dir ||= Rails.root.join('tmp').to_s
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')

    Rails.logger.info("Starting claim PDF check job for date range: #{start_date} to #{end_date}")

    # Step 1: Collect all unique claim IDs from submissions
    submissions = Form526Submission
      .where('created_at >= ? AND created_at <= ?', start_date, end_date)
      .where.not(submitted_claim_id: nil)
      .order(:created_at)

    Rails.logger.info("Found #{submissions.count} Form526Submission records with claim IDs")

    claim_ids = submissions.map(&:submitted_claim_id).uniq
    Rails.logger.info("Found #{claim_ids.count} unique claim IDs")

    # Step 2: For each claim ID, get ICN from a submission and check Lighthouse
    results = []
    missing_pdf_count = 0
    error_count = 0

    claim_ids.each_with_index do |claim_id, index|
      Rails.logger.debug("Processing claim ID #{index + 1}/#{claim_ids.count}: #{claim_id}")

      result = {
        claim_id: claim_id,
        icn: nil,
        has_pdf: nil,
        supporting_documents_count: nil,
        supporting_document_types: [],
        error: nil
      }

      # Find a submission with this claim ID to get ICN
      submission = submissions.find { |s| s.submitted_claim_id == claim_id }
      if submission.nil?
        result[:error] = 'No submission found for claim ID'
        error_count += 1
        Rails.logger.warn("No submission found for claim ID: #{claim_id}")
      else
        result[:icn] = submission.account&.icn

        if result[:icn].blank?
          result[:error] = 'No ICN found for submission'
          error_count += 1
          Rails.logger.warn("No ICN found for claim ID: #{claim_id}")
        else
          Rails.logger.debug("Checking claim ID: #{claim_id} with ICN: #{result[:icn]}")
          # Check Lighthouse for PDF
          begin
            service = BenefitsClaims::Service.new(result[:icn])
            response = service.get_claim(claim_id)

            response_body = if response.is_a?(String)
                              JSON.parse(response)
                            elsif response.is_a?(Hash)
                              response
                            else
                              raise "Invalid response"
                            end

            supporting_docs = response_body.dig('data', 'attributes', 'supportingDocuments')

            if supporting_docs.nil?
              result[:has_pdf] = false
              result[:supporting_documents_count] = 0
              missing_pdf_count += 1
              Rails.logger.debug("No supporting documents for claim ID: #{claim_id}")
            elsif supporting_docs.is_a?(Array)
              form526_pdf = supporting_docs.find do |doc|
                doc['documentTypeLabel'] == 'VA 21-526 Veterans Application for Compensation or Pension'
              end

              result[:supporting_documents_count] = supporting_docs.count
              result[:supporting_document_types] = supporting_docs.map { |d| d['documentTypeLabel'] }.uniq
              result[:has_pdf] = !form526_pdf.nil?

              if form526_pdf.nil?
                missing_pdf_count += 1
                Rails.logger.info("Missing PDF for claim ID: #{claim_id}")
              else
                Rails.logger.debug("Found PDF for claim ID: #{claim_id}")
              end
            else
              result[:error] = 'Invalid supportingDocuments format'
              error_count += 1
              Rails.logger.error("Invalid supportingDocuments format for claim ID: #{claim_id}")
            end
          rescue StandardError => e
            result[:error] = "#{e.class}: #{e.message}"
            error_count += 1
            Rails.logger.error("Error checking claim ID #{claim_id}: #{e.message}")
          end
        end
      end

      results << result
    end

    Rails.logger.info("Check complete!")
    Rails.logger.info("  Total claims processed: #{results.count}")
    Rails.logger.info("  Claims with NO PDF: #{missing_pdf_count}")
    Rails.logger.info("  Errors encountered: #{error_count}")

    # Export results
    json_file = "#{output_dir}/claim_pdf_check_results_#{timestamp}.json"
    File.write(json_file, JSON.pretty_generate({
      metadata: {
        timestamp: Time.now.iso8601,
        date_range: {
          start: start_date.to_s,
          end: end_date.to_s
        },
        total_processed: results.count,
        missing_pdf_count: missing_pdf_count,
        errors: error_count
      },
      results: results
    }))
    Rails.logger.info("Results JSON saved to: #{json_file}")

    # Export claims without PDFs
    missing_pdf_claims = results.select { |r| r[:has_pdf] == false }
    missing_json = "#{output_dir}/claims_no_pdf_#{timestamp}.json"
    File.write(missing_json, JSON.pretty_generate({
      metadata: {
        timestamp: Time.now.iso8601,
        total_missing: missing_pdf_claims.count
      },
      claims_without_pdf: missing_pdf_claims
    }))
    Rails.logger.info("Missing PDF claims JSON saved to: #{missing_json}")

    # Export claim IDs without PDFs (for further processing)
    missing_ids = missing_pdf_claims.map { |r| r[:claim_id] }
    missing_txt = "#{output_dir}/claim_ids_no_pdf_#{timestamp}.txt"
    File.write(missing_txt, missing_ids.join("\n"))
    Rails.logger.info("Missing PDF claim IDs TXT saved to: #{missing_txt}")

    # Upload to S3 (attempts by default, fails gracefully)
    if upload_enabled
      Rails.logger.info("Attempting S3 upload...")

      if s3_bucket.nil? || s3_bucket.empty?
        Rails.logger.warn("S3 upload skipped: No S3 bucket configured (CLAIM_CHECK_S3_BUCKET not set)")
      else
        files_to_upload = [json_file, missing_json, missing_txt]

        s3_client = nil
        begin
          s3_client = Aws::S3::Client.new(region: s3_region)
        rescue StandardError => e
          Rails.logger.error("S3 upload failed: Unable to initialize S3 client - #{e.class}: #{e.message}")
          Rails.logger.error("This may be due to missing AWS credentials or invalid region configuration")
        end

        if s3_client.nil?
          Rails.logger.warn("S3 upload aborted due to client initialization failure")
        else
          upload_success_count = 0
          upload_failure_count = 0

          files_to_upload.each do |file_path|
            next unless File.exist?(file_path)

            s3_key = "#{s3_prefix}#{File.basename(file_path)}"
            begin
              File.open(file_path, 'rb') do |file|
                s3_client.put_object(
                  bucket: s3_bucket,
                  key: s3_key,
                  body: file
                )
              end
              Rails.logger.info("Successfully uploaded #{file_path} to s3://#{s3_bucket}/#{s3_key}")
              upload_success_count += 1
            rescue StandardError => e
              Rails.logger.error("Failed to upload #{file_path} to S3: #{e.class}: #{e.message}")
              Rails.logger.error("S3 upload failed for file: #{File.basename(file_path)}")
              upload_failure_count += 1
            end
          end

          if upload_failure_count > 0
            Rails.logger.warn("S3 upload completed with #{upload_failure_count} failures out of #{files_to_upload.length} files")
            Rails.logger.warn("Check AWS credentials, bucket permissions, and network connectivity")
          else
            Rails.logger.info("S3 upload completed successfully - all #{upload_success_count} files uploaded")
          end
        end
      end
    else
      Rails.logger.info("S3 upload disabled by configuration")
    end
  end

  # Configuration class for handling arguments, config files, and environment variables
  class Config
    attr_accessor :start_date, :end_date, :output_dir, :upload_enabled,
                  :s3_bucket, :s3_region, :s3_prefix, :max_claims

    def initialize
      # Set defaults
      # TODO: Issue #131101 - Add back proper date defaults
      # @end_date = ENV['CLAIM_CHECK_END_DATE'] || Date.today.to_s
      # @start_date = ENV['CLAIM_CHECK_START_DATE'] || (Date.today - 7).to_s
      @end_date = ENV['CLAIM_CHECK_END_DATE'] || '2025-01-10'  # Issue #131101 placeholder
      @start_date = ENV['CLAIM_CHECK_START_DATE'] || '2024-08-19'  # Issue #131101 placeholder
      @output_dir = ENV['CLAIM_CHECK_OUTPUT_DIR'] || Rails.root.join('tmp').to_s
      @upload_enabled = ENV['CLAIM_CHECK_UPLOAD_ENABLED'] != 'false' # Default to true unless explicitly set to 'false'
      @s3_bucket = ENV['CLAIM_CHECK_S3_BUCKET']
      @s3_region = ENV['CLAIM_CHECK_S3_REGION'] || 'us-gov-west-1'
      @s3_prefix = ENV['CLAIM_CHECK_S3_PREFIX'] || 'form526-pdf-checks/'
      @max_claims = (ENV['CLAIM_CHECK_MAX_CLAIMS'] || 1000).to_i
    end

    def load_from_file(config_file)
      return unless File.exist?(config_file)

      config_data = YAML.load_file(config_file)
      return unless config_data.is_a?(Hash)

      @start_date = config_data['start_date'] if config_data['start_date']
      @end_date = config_data['end_date'] if config_data['end_date']
      @output_dir = config_data['output_dir'] if config_data['output_dir']
      @upload_enabled = config_data['upload_enabled'] if config_data.key?('upload_enabled')
      @s3_bucket = config_data['s3_bucket'] if config_data['s3_bucket']
      @s3_region = config_data['s3_region'] if config_data['s3_region']
      @s3_prefix = config_data['s3_prefix'] if config_data['s3_prefix']
      @max_claims = config_data['max_claims'].to_i if config_data['max_claims']
    end

    def parse_args(args)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} [options]"

        opts.on("--start-date DATE", "Start date for submissions (YYYY-MM-DD)") do |date|
          options[:start_date] = date
        end

        opts.on("--end-date DATE", "End date for submissions (YYYY-MM-DD)") do |date|
          options[:end_date] = date
        end

        opts.on("--output-dir DIR", "Output directory for results") do |dir|
          options[:output_dir] = dir
        end

        opts.on("--[no-]upload", "Enable/disable S3 upload") do |upload|
          options[:upload_enabled] = upload
        end

        opts.on("--s3-bucket BUCKET", "S3 bucket name") do |bucket|
          options[:s3_bucket] = bucket
        end

        opts.on("--s3-region REGION", "AWS region") do |region|
          options[:s3_region] = region
        end

        opts.on("--s3-prefix PREFIX", "S3 key prefix") do |prefix|
          options[:s3_prefix] = prefix
        end

        opts.on("--max-claims NUM", Integer, "Maximum claims to process") do |num|
          options[:max_claims] = num
        end

        opts.on("--config FILE", "Configuration file (YAML)") do |file|
          options[:config_file] = file
        end

        opts.on("-h", "--help", "Show this help") do
          puts opts
          exit
        end
      end

      parser.parse!(args)

      # Load config file if specified
      load_from_file(options[:config_file]) if options[:config_file]

      # Override with command line options
      @start_date = options[:start_date] if options.key?(:start_date)
      @end_date = options[:end_date] if options.key?(:end_date)
      @output_dir = options[:output_dir] if options[:output_dir]
      @upload_enabled = options[:upload_enabled] if options.key?(:upload_enabled)
      @s3_bucket = options[:s3_bucket] if options[:s3_bucket]
      @s3_region = options[:s3_region] if options[:s3_region]
      @s3_prefix = options[:s3_prefix] if options[:s3_prefix]
      @max_claims = options[:max_claims] if options[:max_claims]
    end
  end

  # Run as standalone script
  if __FILE__ == $PROGRAM_NAME
    # Load Rails environment
    require 'rails'
    require File.expand_path('../../config/environment', __dir__)

    config = Config.new
    config.parse_args(ARGV)

    puts "Configuration:"
    puts "  Start Date: #{config.start_date}"
    puts "  End Date: #{config.end_date}"
    puts "  Output Dir: #{config.output_dir}"
    puts "  Upload Enabled: #{config.upload_enabled}"
    puts "  S3 Bucket: #{config.s3_bucket || 'Not set'}"
    puts "  S3 Region: #{config.s3_region}"
    puts "  S3 Prefix: #{config.s3_prefix}"
    puts "  Max Claims: #{config.max_claims}"
    puts ""

    # Run the job synchronously
    job = ClaimPdfCheckJob.new
    job.perform(
      config.start_date,
      config.end_date,
      config.output_dir,
      config.upload_enabled,
      config.s3_bucket,
      config.s3_region,
      config.s3_prefix
    )
  end
end