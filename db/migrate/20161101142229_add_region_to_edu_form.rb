class AddRegionToEduForm < ActiveRecord::Migration[4.2]
  def up
    add_column :education_benefits_claims, :regional_processing_office, :string
    EducationBenefitsClaim.all.each {|claim|
      claim.send(:set_region) && claim.save
    }
    change_column :education_benefits_claims, :regional_processing_office, :string, :null => false
  end

  def down
    remove_column :education_benefits_claims, :regional_processing_office
  end
end
