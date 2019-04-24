class AddVettecToEducationBenefitsSubmissions < ActiveRecord::Migration[4.2]
  def change
    add_column :education_benefits_submissions, :vettec, :boolean
  end
end
