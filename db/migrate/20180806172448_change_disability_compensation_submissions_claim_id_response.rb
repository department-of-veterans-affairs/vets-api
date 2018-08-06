class ChangeDisabilityCompensationSubmissionsClaimIdResponse < ActiveRecord::Migration
  def change
    remove_column :disability_compensation_submissions, :claim_id
    add_column :disability_compensation_submissions, :response, :json, unique: false, null: true
  end
end
