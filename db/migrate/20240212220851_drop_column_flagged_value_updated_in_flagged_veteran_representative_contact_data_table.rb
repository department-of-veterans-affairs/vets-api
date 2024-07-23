class DropColumnFlaggedValueUpdatedInFlaggedVeteranRepresentativeContactDataTable < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :flagged_veteran_representative_contact_data, :flagged_value_updated }
  end
end
