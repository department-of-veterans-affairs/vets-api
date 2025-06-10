# frozen_string_literal: true

namespace :burials do
  desc 'Migrate SavedClaim::Burial records to Burials::SavedClaim'
  task migrate_saved_claim_pension_to_pensions_saved_claim: :environment do
    batch_size = 1000
    total = SavedClaim.where(type: 'SavedClaim::Burial').count
    migrated = 0

    puts "Starting migration of SavedClaim::Burial to Burials::SavedClaim (#{total} records)..."

    loop do
      # Use ActiveRecord to select IDs (no instantiation, just pluck)
      ids = SavedClaim.unscoped.where(type: 'SavedClaim::Burial').limit(batch_size).pluck(:id)
      break if ids.empty?

      begin
        # Update the type column directly in the database using raw SQL, so Rails does not
        # instantiate the model and does not attempt decryption.
        # Error without: KmsEncrypted::DecryptionError: Decryption failed
        ActiveRecord::Base.connection.execute(
          "UPDATE saved_claims SET type = 'Burials::SavedClaim' WHERE id IN (#{ids.join(',')})"
        )
        migrated += ids.size
        puts "Migrated batch of #{ids.size} (#{migrated}/#{total})"
      rescue => e
        Rails.logger.error("Failed to migrate SavedClaim IDs #{ids.inspect}: #{e.class}: #{e.message}")
        puts "Error migrating SavedClaim IDs #{ids.inspect}: #{e.class}: #{e.message}"
      end
    end

    puts "Migration complete. Migrated #{migrated} records."
  end
end
