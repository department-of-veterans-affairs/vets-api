class AddChapter35 < ActiveRecord::Migration
  def change
    add_column(:education_benefits_submissions, :chapter_35, :boolean, default: false, null: false)
  end
end
