class AddToxicExposureToForm526Submissions < ActiveRecord::Migration[7.1]
  def change
    add_column :form526_submissions, :toxic_exposure, :boolean, default: false
  end
end
