class MigrateSavedClaimPensionToPensionsSavedClaim < ActiveRecord::Migration[7.2]
  BATCH_SIZE = 1000

  disable_ddl_transaction!

  def up
    say_with_time "Migrating SavedClaim::Pension to Pensions::SavedClaim" do
      loop do
        ids = SavedClaim.where(type: 'SavedClaim::Pension').limit(BATCH_SIZE).pluck(:id)
        break if ids.empty?

        begin
          SavedClaim.where(id: ids).update_all(type: 'Pensions::SavedClaim')
        rescue => e
          Rails.logger.error("MigrateSavedClaimPensionToPensionsSavedClaim batch failed for IDs: #{ids.inspect} - #{e.class}: #{e.message}")
          raise
        end
      end
    end
  end

  def down
    say_with_time "Reverting Pensions::SavedClaim to SavedClaim::Pension" do
      loop do
        ids = SavedClaim.where(type: 'Pensions::SavedClaim').limit(BATCH_SIZE).pluck(:id)
        break if ids.empty?

        begin
          SavedClaim.where(id: ids).update_all(type: 'SavedClaim::Pension')
        rescue => e
          Rails.logger.error("MigrateSavedClaimPensionToPensionsSavedClaim rollback batch failed for IDs: #{ids.inspect} - #{e.class}: #{e.message}")
          raise
        end
      end
    end
  end
end
