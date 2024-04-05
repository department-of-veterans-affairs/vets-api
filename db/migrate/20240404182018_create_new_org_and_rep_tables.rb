class CreateNewOrgAndRepTables < ActiveRecord::Migration[7.1]
  # rubocop:disable Metrics/MethodLength
  def change
    create_table :accredited_representatives, id: false do |t|
      t.string :registration_number, null: false
      t.string :poa_code
      t.string :types, array: true
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
      t.geography :location, limit: { srid: 4326, type: 'st_point', geographic: true }
      t.timestamps
    end
    # rubocop:enable Metrics/MethodLength
    safety_assured do
      execute 'ALTER TABLE accredited_representatives ADD PRIMARY KEY (registration_number);' # rubocop:disable Rails/ReversibleMigration
    end
    add_index :accredited_representatives, :full_name
    add_index :accredited_representatives, :location, using: :gist
    add_index :accredited_representatives, :registration_number, unique: true

    create_table :accredited_organizations, id: false do |t|
      t.string :poa_code, limit: 3, null: false
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
      t.geography :location, limit: { srid: 4326, type: 'st_point', geographic: true }
      t.timestamps
    end
    safety_assured do
      execute 'ALTER TABLE accredited_organizations ADD PRIMARY KEY (poa_code);' # rubocop:disable Rails/ReversibleMigration
    end
    add_index :accredited_organizations, :location, using: :gist
    add_index :accredited_organizations, :name
    add_index :accredited_organizations, :poa_code, unique: true

    create_table :accredited_organization_accredited_representatives, id: false do |t|
      t.string :accredited_representative_registration_number
      t.string :accredited_organization_poa_code
    end
    add_index :accredited_organization_accredited_representatives,
              %i[accredited_representative_registration_number accredited_organization_poa_code], unique: true, name: 'index_organization_representatives_on_rep_and_org' # rubocop:disable Layout/LineLength
    add_foreign_key :accredited_organization_accredited_representatives, :accredited_representatives,
                    column: :accredited_representative_registration_number, primary_key: :registration_number, validate: false
    add_foreign_key :accredited_organization_accredited_representatives, :accredited_organizations,
                    column: :accredited_organization_poa_code, primary_key: :poa_code, validate: false
  end
end