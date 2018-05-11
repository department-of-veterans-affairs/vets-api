class AddChapter35 < ActiveRecord::Migration
  safety_assured

  def change
    add_column(:education_benefits_submissions, :chapter35, :boolean, default: false, null: false)
  end
end
