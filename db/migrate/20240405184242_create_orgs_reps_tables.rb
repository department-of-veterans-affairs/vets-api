# frozen_string_literal: true

class CreateOrgsRepsTables < ActiveRecord::Migration[7.1]
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def change
    create_table :accredited_attorneys, id: :uuid do |t|
      t.string :registration_number, null: false
      t.string :poa_code, limit: 3, null: false
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
    add_index :accredited_attorneys, :registration_number, unique: true
    add_index :accredited_attorneys, :poa_code, unique: true
    add_index :accredited_attorneys, :full_name
    add_index :accredited_attorneys, :location, using: :gist

    create_table :accredited_claims_agents, id: :uuid do |t|
      t.string :registration_number, null: false
      t.string :poa_code, limit: 3, null: false
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
    add_index :accredited_claims_agents, :registration_number, unique: true
    add_index :accredited_claims_agents, :poa_code, unique: true
    add_index :accredited_claims_agents, :full_name
    add_index :accredited_claims_agents, :location, using: :gist

    create_table :accredited_representatives, id: :uuid do |t|
      t.string :registration_number, null: false
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
    add_index :accredited_representatives, :registration_number, unique: true
    add_index :accredited_representatives, :full_name
    add_index :accredited_representatives, :location, using: :gist

    create_table :accredited_organizations, id: :uuid do |t|
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
    add_index :accredited_organizations, :location, using: :gist
    add_index :accredited_organizations, :name

    create_join_table :accredited_organizations, :accredited_representatives, column_options: { type: :uuid } do |t|
      t.uuid :accredited_organization_uuid, null: false, index: true
      t.uuid :accredited_representative_uuid, null: false, index: true
    end
    add_index :accredited_organizations_accredited_representatives,
              [:accredited_organization_uuid, :accredited_representative_uuid],
              unique: true,
              name: 'index_orgs_reps_on_organization_uuid_and_representative_uuid'
      end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
