# frozen_string_literal: true

namespace :persistent_attachments do
  desc "Update type from 'PersistentAttachments::PensionBurial' to 'PersistentAttachments::ClaimEvidence'"
  task backfill_pension_burial_to_claim_evidence: :environment do
    batch_size = 1000
    total = PersistentAttachment.unscoped.where(type: 'PersistentAttachments::PensionBurial').count
    migrated = 0
    failed = 0

    puts "Starting update of PensionBurial to PersistentAttachments::ClaimEvidence (#{total} records)..."

    PersistentAttachment
      .unscoped
      .where(type: 'PersistentAttachments::PensionBurial')
      .find_in_batches(batch_size:) do |batch|
        batch.each do |record|
          record.type = 'PersistentAttachments::ClaimEvidence'
          record.save!(validate: false)
          migrated += 1
        rescue => e
          failed += 1
          Rails.logger.error("Failed to update PersistentAttachment ID #{record.id}: #{e.class}: #{e.message}")
          puts "Error updating PersistentAttachment ID #{record.id}: #{e.class}: #{e.message}"
        end
        puts "Processed batch of #{batch.size} (#{migrated}/#{total} migrated, #{failed} failed)"
      end

    puts "Update complete. Migrated #{migrated} records. Failed: #{failed}."
  end
end
