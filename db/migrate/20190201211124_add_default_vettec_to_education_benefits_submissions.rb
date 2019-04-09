class AddDefaultVettecToEducationBenefitsSubmissions < ActiveRecord::Migration[4.2]
  def change
    change_column_default :education_benefits_submissions, :vettec, false
  end
end
