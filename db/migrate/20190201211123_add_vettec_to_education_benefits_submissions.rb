class AddVettecToEducationBenefitsSubmissions < ActiveRecord::Migration
  def change
    add_column :education_benefits_submissions, :vettec, :boolean, default: false, null: false
  end
end
