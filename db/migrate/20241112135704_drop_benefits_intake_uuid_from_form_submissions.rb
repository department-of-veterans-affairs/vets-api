class DropBenefitsIntakeUuidFromFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :form_submissions, :benefits_intake_uuid, :uuid, if_exists: true }
  end
end