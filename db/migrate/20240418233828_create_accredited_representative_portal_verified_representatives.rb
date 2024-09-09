# frozen_string_literal: true
# NOTE: This table was renamed and then dropped in the migration `DropAccreditedRepresentativePortalPilotRepresentatives`
class CreateAccreditedRepresentativePortalVerifiedRepresentatives < ActiveRecord::Migration[7.1]
  def change
    create_table :accredited_representative_portal_verified_representatives do |t|
      t.string :ogc_registration_number, null: false
      t.string :email, null: false

      t.timestamps

      t.index 'ogc_registration_number', unique: true, name: 'index_verified_representatives_on_ogc_number'
      t.index 'email', unique: true, name: 'index_verified_representatives_on_email'
    end
  end
end
