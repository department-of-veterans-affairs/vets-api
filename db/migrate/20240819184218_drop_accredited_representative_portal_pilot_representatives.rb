class DropAccreditedRepresentativePortalPilotRepresentatives < ActiveRecord::Migration[6.0]
  def up
    drop_table :accredited_representative_portal_pilot_representatives, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
