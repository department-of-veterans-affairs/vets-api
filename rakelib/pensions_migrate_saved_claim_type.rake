# frozen_string_literal: true

namespace :pensions do
  desc 'Re-encrypt and migrate SavedClaim::Pension records to Pensions::SavedClaim'
  task migrate_saved_claim_pension_to_pensions_saved_claim: :environment do
    batch_size = 100
    total = SavedClaim.unscoped.where(type: 'SavedClaim::Pension').count
    migrated = 0
    failed = 0

    puts "Starting re-encryption and migration of SavedClaim::Pension to Pensions::SavedClaim (#{total} records)..."

    # Use unscoped to avoid STI instantiation issues
    SavedClaim.unscoped.
      where(type: 'SavedClaim::Pension').
      find_in_batches(batch_size: batch_size) do |batch|
        batch.each do |record|
          begin
            # Decrypt the form data using the old context
            form_data = record.form

            # Update the type and re-encrypt by saving
            record.type = 'Pensions::SavedClaim'
            record.form = form_data # triggers re-encryption with new context
            record.save!(validate: false)
            migrated += 1
            puts "Migrated and re-encrypted SavedClaim ID #{record.id} (#{migrated}/#{total})"
          rescue => e
            failed += 1
            Rails.logger.error("Failed to migrate/re-encrypt SavedClaim ID #{record.id}: #{e.class}: #{e.message}")
            puts "Error migrating/re-encrypting SavedClaim ID #{record.id}: #{e.class}: #{e.message}"
          end
        end
      end

    puts "Migration complete. Migrated #{migrated} records. Failed: #{failed}."
  end
end