class AddChapter35 < ActiveRecord::Migration[4.2]
  def change
    add_column(:education_benefits_submissions, :chapter35, :boolean, default: false, null: false)
  end
end
