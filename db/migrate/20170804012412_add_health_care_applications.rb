class AddHealthCareApplications < ActiveRecord::Migration
  def change
    create_table "health_care_applications" do |t|
      t.timestamps(null: false)
      t.string(:state, null: false, default: 'pending')
      t.string(:form_submission_id_string)
      t.string(:timestamp)
    end
  end
end
