class AddFormTypeToEducationBenefitsClaims < ActiveRecord::Migration[4.2]
  safety_assured
  def change
    add_column(:education_benefits_claims, :form_type, :string, null: false, default: '1990')
  end
end
