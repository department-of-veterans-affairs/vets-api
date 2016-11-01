class AddRegionToEduForm < ActiveRecord::Migration
  def change
    add_column :education_benefits_claims, :regional_processing_office, :string
  end
end
