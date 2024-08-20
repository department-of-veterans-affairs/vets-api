class DropAccreditedRepresentativePortalPilotRepresentatives < ActiveRecord::Migration[6.0]
  def change
    drop_table :accredited_representative_portal_pilot_representatives do |t|
      t.string "ogc_registration_number", null: false
      t.string "email", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
  end
end
