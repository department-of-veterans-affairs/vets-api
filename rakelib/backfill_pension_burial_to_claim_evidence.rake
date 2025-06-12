# frozen_string_literal: true

namespace :persistent_attachments do
  desc "Update type from 'PersistentAttachments::PensionBurial' to 'PersistentAttachments::ClaimEvidence'"
  task backfill_pension_burial_to_claim_evidence: :environment do
    batch_size = 1000
    total = PersistentAttachment.unscoped.where(type: 'PersistentAttachments::PensionBurial').count
    migrated = 0

    puts "Starting update of PersistentAttachments::PensionBurial to PersistentAttachments::ClaimEvidence (#{total} records)..."

    PersistentAttachment.unscoped
      .where(type: 'PersistentAttachments::PensionBurial')
      .find_in_batches(batch_size: batch_size) do |batch|
        ids = batch.map(&:id)
        PersistentAttachment.unscoped.where(id: ids)
          .update_all(type: 'PersistentAttachments::ClaimEvidence')
        migrated += ids.size
        puts "Updated batch of #{ids.size} (#{migrated}/#{total})"
      end

    puts "Update complete. Updated #{migrated} records."
  end
end