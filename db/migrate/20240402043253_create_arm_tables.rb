class CreateArmTables < ActiveRecord::Migration[7.1]
  def change
    create_table :accredited_representatives, id: false do |t|
      t.string :number, null: false
      t.string :poa_code
      t.string :first_name
      t.string :middle_initial
      t.string :last_name
      t.string :full_name
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
      t.geography :location, limit: {srid: 4326, type: 'st_point', geographic: true}
      t.timestamps
    end

    safety_assured do
      execute "ALTER TABLE accredited_representatives ADD PRIMARY KEY (number);"
    end

    add_index :accredited_representatives, :full_name
    add_index :accredited_representatives, :location, using: :gist
    add_index :accredited_representatives, [:number, :first_name, :last_name], unique: true, name: 'index_rep_group'
 
    create_table :accredited_organizations, id: false do |t|
      t.string :poa, limit: 3, null: false
      t.string :name
      t.string :phone
      t.string :state, limit: 2
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
      t.geography :location, limit: {srid: 4326, type: 'st_point', geographic: true}
      t.timestamps
    end
    safety_assured do
      execute "ALTER TABLE accredited_organizations ADD PRIMARY KEY (poa);"
    end

    add_index :accredited_organizations, :location, using: :gist
    add_index :accredited_organizations, :name
    add_index :accredited_organizations, :poa, unique: true

    create_table :accredited_representative_types, id: false do |t|
      t.string :accredited_representative_number
      t.string :type
    end
    add_index :accredited_representative_types, [:accredited_representative_number, :type], unique: true, name: 'index_accredited_representative_types_on_id_and_type'
    add_foreign_key :accredited_representative_types, :accredited_representatives, column: :accredited_representative_number, primary_key: :number, validate: false

    create_table :accredited_organization_accredited_representatives, id: false do |t|
      t.string :accredited_representative_number
      t.string :accredited_organization_poa
    end
    add_index :accredited_organization_accredited_representatives, [:accredited_representative_number, :accredited_organization_poa], unique: true, name: 'index_organization_representatives_on_rep_and_org'
    add_foreign_key :accredited_organization_accredited_representatives, :accredited_representatives, column: :accredited_representative_number, primary_key: :number, validate: false
    add_foreign_key :accredited_organization_accredited_representatives, :accredited_organizations, column: :accredited_organization_poa, primary_key: :poa, validate: false
  end
end
