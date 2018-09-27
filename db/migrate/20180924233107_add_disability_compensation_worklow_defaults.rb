class AddDisabilityCompensationWorklowDefaults < ActiveRecord::Migration
  def change
    change_column_default :disability_compensation_submissions, :has_uploads, false
    change_column_default :disability_compensation_submissions, :uploads_success, false
    change_column_default :disability_compensation_submissions, :has_form_4142, false
    change_column_default :disability_compensation_submissions, :form_4142_success, false
  end
end
