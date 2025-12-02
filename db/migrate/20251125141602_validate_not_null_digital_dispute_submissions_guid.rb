# frozen_string_literal: true

class ValidateNotNullDigitalDisputeSubmissionsGuid < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    validate_check_constraint :digital_dispute_submissions, name: 'digital_dispute_submissions_guid_null'
    change_column_null :digital_dispute_submissions, :guid, false
    remove_check_constraint :digital_dispute_submissions, name: 'digital_dispute_submissions_guid_null'
  end

  def down
    add_check_constraint :digital_dispute_submissions,
                         'guid IS NOT NULL',
                         name: 'digital_dispute_submissions_guid_null',
                         validate: false
    change_column_null :digital_dispute_submissions, :guid, true
  end
end
