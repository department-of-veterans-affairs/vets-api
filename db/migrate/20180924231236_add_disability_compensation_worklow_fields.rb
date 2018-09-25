class AddDisabilityCompensationWorklowFields < ActiveRecord::Migration
  def change
    add_column :disability_compensation_submissions, :has_uploads, :boolean
    add_column :disability_compensation_submissions, :uploads_success, :boolean
    add_column :disability_compensation_submissions, :has_form_4142, :boolean
    add_column :disability_compensation_submissions, :form_4142_success, :boolean
  end
end
