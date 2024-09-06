# NOTE: This table was dropped in the migration `DropAccreditedRepresentativePortalPilotRepresentatives`
class CreateAccreditedRepresentativePortalPilotRepresentatives < ActiveRecord::Migration[7.1]
  def change
    create_table :accredited_representative_portal_pilot_representatives do |t|
      t.string :ogc_registration_number, null: false
      t.string :email, null: false

      t.timestamps

      t.index 'ogc_registration_number', unique: true, name: 'index_pilot_representatives_on_ogc_number'
      t.index 'email', unique: true, name: 'index_pilot_representatives_on_email'
    end
  end
end
