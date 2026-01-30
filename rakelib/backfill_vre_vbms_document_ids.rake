# frozen_string_literal: true

# Rake task to backfill VRE VBMS document IDs for claims with incorrect signature dates
# This fixes claims submitted between 1/14/2026 and 1/24/2026 by:
# 1. Updating the signature date to match the claim creation date
# 2. Re-uploading the claim to VBMS to generate a new document ID
#
# Usage:
#   bundle exec rake vre:backfill_vbms_document_ids
#
#   With custom date range:
#   bundle exec rake vre:backfill_vbms_document_ids START_DATE=2026-01-14 END_DATE=2026-01-24

namespace :vre do
  desc 'Backfill VBMS document IDs for VRE claims and correct signature dates'
  task backfill_vbms_document_ids: :environment do
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

    unless Object.const_defined?('VreVbmsDocumentIdBackfillWorker')
      class VreVbmsDocumentIdBackfillWorker
        include Sidekiq::Worker
        sidekiq_options queue: 'default', retry: 5

        def perform(claim_id)
          claim = SavedClaim::VeteranReadinessEmploymentClaim.find(claim_id)
          updated_form = claim.parsed_form
          updated_form['signatureDate'] = claim.created_at.to_date
          claim.update!(form: updated_form.to_json)

          uuid = claim.user_account.present? ? claim.user_account.id : 'manual-run-missing-user-account'
          claim.upload_to_vbms(user: OpenStruct.new(uuid:))

          Rails.logger.info "VRE_VBMS_BACKFILL_SUCCESS: Claim ID #{claim_id} processed successfully"
        rescue => e
          Rails.logger.error "VRE_VBMS_BACKFILL_FAILURE: Claim ID #{claim_id} - #{e.class}: #{e.message}"
          raise # Re-raise to trigger Sidekiq retry
        end
      end
    end

    # Enqueue jobs in batches
    puts "Enqueuing #{claim_ids.count} jobs..."
    total_enqueued = 0

    claim_ids.each_slice(100) do |batch|
      batch.each do |id|
        VreVbmsDocumentIdBackfillWorker.perform_async(id)
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
