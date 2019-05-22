class SubmissionChangesFor0994 < ActiveRecord::Migration[4.2]
  def add
    add_column(:education_benefits_submissions, :vettec, :boolean, default: false, null: false)
  end
end
