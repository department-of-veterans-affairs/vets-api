class AddDeactivatedAtToAccreditedIndividuals < ActiveRecord::Migration[7.2]
  def change
    add_column :accredited_individuals, :deactivated_at, :datetime, null: true, default: nil
  end
end
