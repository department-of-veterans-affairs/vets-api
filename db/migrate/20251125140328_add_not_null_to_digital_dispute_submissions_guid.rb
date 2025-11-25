# frozen_string_literal: true

class AddNotNullToDigitalDisputeSubmissionsGuid < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :digital_dispute_submissions, 'guid IS NOT NULL', name: 'digital_dispute_submissions_guid_null', validate: false
  end
end
