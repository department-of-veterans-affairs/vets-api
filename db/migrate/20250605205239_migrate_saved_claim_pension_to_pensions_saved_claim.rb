class MigrateSavedClaimPensionToPensionsSavedClaim < ActiveRecord::Migration[7.2]
  def up
    # Update all records with the old STI type to the new one
    SavedClaim.where(type: 'SavedClaim::Pension').update_all(type: 'Pensions::SavedClaim')
  end

  def down
    # Rollback: revert to the old type
    SavedClaim.where(type: 'Pensions::SavedClaim').update_all(type: 'SavedClaim::Pension')
  end
end
