class MigrateSavedClaimPensionToPensionsSavedClaim < ActiveRecord::Migration[7.2]
  BATCH_SIZE = 1000

  disable_ddl_transaction!

  def change
    safety_assured do
      loop do
        ids = SavedClaim.where(type: 'SavedClaim::Pension').limit(BATCH_SIZE).pluck(:id)
        break if ids.empty?

        begin
          SavedClaim.where(id: ids).update_all(type: 'Pensions::SavedClaim')
        rescue => e
          Rails.logger.error("MigrateSavedClaimPensionToPensionsSavedClaim batch failed for IDs: #{ids.inspect} - #{e.class}: #{e.message}")
        end
      end
    end
  end
end
