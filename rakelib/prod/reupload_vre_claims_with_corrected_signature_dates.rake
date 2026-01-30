# frozen_string_literal: true

# Rake task to reupload VRE claims with corrected signature dates
# This fixes claims submitted between 1/14/2026 and 1/24/2026 by:
# 1. Updating the signature date to match the claim creation date
# 2. Re-uploading the claim to VBMS to generate a new document ID
#
# Usage:
#   bundle exec rake vre:reupload_vre_claims_with_corrected_signature_dates
#
#   With custom date range:
#   bundle exec rake vre:reupload_vre_claims_with_corrected_signature_dates START_DATE=2026-01-14 END_DATE=2026-01-24

namespace :vre do
  desc 'Reupload VRE claims with corrected signature dates'
  task reupload_vre_claims_with_corrected_signature_dates: :environment do
    # Parse date parameters or use defaults
    start_date = ENV['START_DATE'] ? Date.parse(ENV['START_DATE']) : Date.new(2026, 1, 14)
    end_date = ENV['END_DATE'] ? Date.parse(ENV['END_DATE']) : Date.new(2026, 1, 24)

    puts '=' * 80
    puts 'VRE VBMS Document ID Backfill'
    puts '=' * 80
    puts "Start Date: #{start_date}"
    puts "End Date: #{end_date}"
    puts '=' * 80

    # Collect the IDs of affected claims
    puts 'Collecting claim IDs...'
    claim_ids = SavedClaim::VeteranReadinessEmploymentClaim
                .where('created_at > ?', start_date)
                .where('created_at < ?', end_date)
                .where(form_id: '28-1900')
                .pluck(:id)

    puts "Found #{claim_ids.count} claims to process"

    if claim_ids.empty?
      puts 'No claims found. Exiting.'
      exit
    end

    # Enqueue jobs in batches
    puts "Enqueuing #{claim_ids.count} jobs..."
    total_enqueued = 0

    claim_ids.each_slice(100) do |batch|
      batch.each do |id|
        VREVBMSDocumentUploadJob.perform_async(id)
        total_enqueued += 1
      end
      puts "Enqueued #{total_enqueued}/#{claim_ids.count} claims..."
    end

    puts '=' * 80
    puts "✓ Successfully enqueued #{total_enqueued} claims for processing"
    puts 'Monitor progress in Sidekiq dashboard or Rails logs'
    puts '=' * 80
  end
end
