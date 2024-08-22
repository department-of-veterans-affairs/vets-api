class DropAccreditedRepresentativePortalPilotRepresentatives < ActiveRecord::Migration[6.0]
  def change
    drop_table :accredited_representative_portal_pilot_representatives
  end
end
