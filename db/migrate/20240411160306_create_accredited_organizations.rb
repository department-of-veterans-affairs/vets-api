# frozen_string_literal: true

class CreateAccreditedOrganizations < ActiveRecord::Migration[7.1]
  def change
    create_table :accredited_organizations, id: :uuid do |t|
      t.uuid :ogc_id, null: false
      t.string :poa_code, limit: 3, null: false, index: { unique: true }
      t.string :name, index: true
      t.string :phone
      t.string :address_type
      t.string :address_line1
      t.string :address_line2
      t.string :address_line3
      t.string :city
      t.string :country_code_iso3
      t.string :country_name
      t.string :county_name
      t.string :county_code
      t.string :international_postal_code
      t.string :province
      t.string :state_code
      t.string :zip_code
      t.string :zip_suffix
      t.jsonb :raw_address
      t.float :lat
      t.float :long
      t.geography :location, limit: { srid: 4326, type: 'st_point', geographic: true }
      t.timestamps

      t.index :location, using: :gist
    end
  end
end
