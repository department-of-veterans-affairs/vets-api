# frozen_string_literal: true

class CreateAccreditedIndividuals < ActiveRecord::Migration[7.1]
  def change
    create_table :accredited_individuals, id: :uuid do |t|
      t.uuid :ogc_id, null: false
      t.string :registration_number, null: false
      t.string :poa_code, limit: 3, index: true
      t.string :individual_type, null: false
      t.string :first_name
      t.string :middle_initial
      t.string :last_name
      t.string :full_name, index: true
      t.string :email
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
      t.index %i[ registration_number individual_type ], name: 'index_on_reg_num_and_type_for_accredited_individuals', unique: true
    end
  end
end
