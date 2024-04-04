# frozen_string_literal: true

class UpdateAndRemoveOrgRepTableColumns < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      # Removing foreign key constraints
      remove_foreign_key :accredited_organization_accredited_representatives, :accredited_representatives,
                         column: :accredited_representative_number
      remove_foreign_key :accredited_organization_accredited_representatives, :accredited_organizations,
                         column: :accredited_organization_poa

      # Removing the old primary key columns
      remove_column :accredited_representatives, :number, :string
      remove_column :accredited_organizations, :poa, :string

      # Renaming the foreign key columns
      rename_column :accredited_organization_accredited_representatives, :accredited_representative_number, :representative_id
      rename_column :accredited_organization_accredited_representatives, :accredited_organization_poa, :organization_poa_code
      
      # Ensure the new columns are unique before setting them as primary keys
      add_index :accredited_representatives, :representative_id, unique: true, name: 'unique_index_on_representative_id'
      add_index :accredited_organizations, :poa_code, unique: true, name: 'unique_index_on_poa_code'

      # Change the primary key to the new column
      execute "ALTER TABLE accredited_representatives ADD PRIMARY KEY (representative_id);"
      execute "ALTER TABLE accredited_organizations ADD PRIMARY KEY (poa_code);"

      # Adding new foreign key constraints with the renamed columns and new primary keys
      add_foreign_key :accredited_organization_accredited_representatives, :accredited_representatives,
                      column: :representative_id, primary_key: :representative_id
      add_foreign_key :accredited_organization_accredited_representatives, :accredited_organizations,
                      column: :organization_poa_code, primary_key: :poa_code
    end
  end
end
