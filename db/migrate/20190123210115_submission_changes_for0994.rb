class SubmissionChangesFor0994 < ActiveRecord::Migration
  def add
    add_column(:education_benefits_submissions, :vettec, :boolean, default: false, null: false)
  end
end
