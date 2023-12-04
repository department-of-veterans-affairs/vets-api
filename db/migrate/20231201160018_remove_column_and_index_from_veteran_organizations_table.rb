class RemoveColumnAndIndexFromVeteranOrganizationsTable < ActiveRecord::Migration[6.1]

  def change
    safety_assured { remove_column :veteran_organizations, :representative_number }
  end
end
