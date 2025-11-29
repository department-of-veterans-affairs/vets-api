# frozen_string_literal: true

class AddNewIdToDigitalDisputeSubmissions < ActiveRecord::Migration[7.2]
  def up
    add_column :digital_dispute_submissions, :new_id, :bigint

    safety_assured do
      execute <<-SQL.squish
        CREATE SEQUENCE digital_dispute_submissions_new_id_seq;
      SQL
    end
  end
end
