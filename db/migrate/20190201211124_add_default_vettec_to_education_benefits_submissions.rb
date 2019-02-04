class AddDefaultVettecToEducationBenefitsSubmissions < ActiveRecord::Migration
  def change
    change_column_default :education_benefits_submissions, :vettec, false
  end
end
