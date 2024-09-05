class CreateStdInstitutionFacilities < ActiveRecord::Migration[7.1]
  def change
    create_table :std_institution_facilities do |t|
      t.date :activation_date
      t.date :deactivation_date
      t.string :name
      t.string :station_number
      t.string :vista_name
      t.integer :agency_id
      t.integer :street_country_id
      t.string :street_address_line1
      t.string :street_address_line2
      t.string :street_address_line3
      t.string :street_city
      t.integer :street_state_id
      t.integer :street_county_id
      t.string :street_postal_code
      t.integer :mailing_country_id
      t.string :mailing_address_line1
      t.string :mailing_address_line2
      t.string :mailing_address_line3
      t.string :mailing_city
      t.integer :mailing_state_id
      t.integer :mailing_county_id
      t.string :mailing_postal_code
      t.integer :facility_type_id
      t.integer :mfn_zeg_recipient
      t.integer :parent_id
      t.integer :realigned_from_id
      t.integer :realigned_to_id
      t.integer :visn_id
      t.integer :version
      t.datetime :created
      t.datetime :updated
      t.string :created_by
      t.string :updated_by

      t.timestamps
    end
  end
end
