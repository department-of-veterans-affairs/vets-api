# frozen_string_literal: true

class AddNewPrimaryKeyColumnsToOrgRepTables < ActiveRecord::Migration[7.1]
  def change
    def change
      add_column :accredited_representatives, :representative_id, :string
      add_column :accredited_organizations, :poa_code, :string, limit: 3
    end
  end
end
