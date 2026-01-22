class AddFallbackLocationUpdatedAtToAccreditedIndividual < ActiveRecord::Migration[7.2]
  def change
    add_column :accredited_individuals, :fallback_location_updated_at, :datetime
    add_column :veteran_representatives, :fallback_location_updated_at, :datetime
  end
end
