class FixDigitalDisputeSubmissionsSequence < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      execute <<-SQL
        -- Create the missing sequence only if it doesn't exist
        CREATE SEQUENCE IF NOT EXISTS digital_dispute_submissions_new_id_seq;

        -- Set it to start after the current max id value
        SELECT setval('digital_dispute_submissions_new_id_seq',
          COALESCE((SELECT MAX(id) FROM digital_dispute_submissions), 0) + 1,
          false);
      SQL
    end
  end

  def down
    safety_assured do
      execute "DROP SEQUENCE IF EXISTS digital_dispute_submissions_new_id_seq;"
    end
  end
end