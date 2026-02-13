# frozen_string_literal: true

# Rake task to log VRE (Ch. 31) claims data for claims submitted between dates provided
# This logs claims submitted between 1/14/2026 and 1/24/2026 by:
# 1. Collecting claim IDs
# 2. Enqueuing jobs to log claim data specified in VREVBMSDocumentUploadLogJob
#
# Usage:
#   bundle exec rake vre:claims_batch_log
#
#   With custom date range:
#   bundle exec rake vre:claims_batch_log START_DATE=2026-01-14 END_DATE=2026-01-24

namespace :vre do
  desc 'Log VRE (Ch. 31) claims data for claims submitted between dates provided'
  task claims_batch_log: :environment do
    # Parse date parameters or use defaults
    start_date = ENV['START_DATE'] ? Date.parse(ENV['START_DATE']) : Date.new(2026, 1, 14)
    end_date = ENV['END_DATE'] ? Date.parse(ENV['END_DATE']) : Date.new(2026, 1, 24)

    puts '=' * 80
    puts 'VRE Claims Batch Log'
    puts '=' * 80
    puts "Start Date: #{start_date}"
    puts "End Date: #{end_date}"
    puts '=' * 80

    # Collect the IDs of affected claims
    puts 'Collecting claim IDs...'
    claim_ids = SavedClaim::VeteranReadinessEmploymentClaim
                .where('created_at >= ?', start_date)
                .where('created_at <= ?', end_date)
                .where(form_id: '28-1900')
                .pluck(:id)

    puts "Found #{claim_ids.count} claims to process"

    if claim_ids.empty?
      puts 'No claims found. Exiting.'
      exit
    end

    # Enqueue jobs in batches with rate limiting
    puts "Enqueuing #{claim_ids.count} jobs..."
    batch_size = 500
    delay_between_batches = 2 # seconds

    claim_ids.each_slice(batch_size).with_index do |batch, batch_index|
      batch.each do |id|
        VREVBMSDocumentUploadLogJob.perform_async(id)
      end

      enqueued_so_far = [(batch_index + 1) * batch_size, claim_ids.count].min
      puts "Enqueued #{enqueued_so_far}/#{claim_ids.count} claims..."

      # Rate limit to avoid overwhelming Sidekiq queue and VBMS service
      sleep(delay_between_batches) unless batch_index == (claim_ids.count.to_f / batch_size).ceil - 1
    end

    puts '=' * 80
    puts "✓ Successfully enqueued #{claim_ids.count} claims for processing"
    puts 'Monitor progress in Sidekiq dashboard or Rails logs'
    puts '=' * 80
  end
end
