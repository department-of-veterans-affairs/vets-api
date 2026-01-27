class FixDigitalDisputeSubmissionsSequence < ActiveRecord::Migration[7.2]
  def up
    # Wrap in safety_assured since creating a sequence is safe
    safety_assured do
      execute <<-SQL
        DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = 'digital_dispute_submissions_new_id_seq') THEN
            CREATE SEQUENCE digital_dispute_submissions_new_id_seq;

            -- Set the sequence to the current max ID + 1
            PERFORM setval('digital_dispute_submissions_new_id_seq',
              COALESCE((SELECT MAX(id) FROM digital_dispute_submissions), 0) + 1,
              false);
          END IF;
        END $$;
      SQL
    end
  end

  def down
    safety_assured do
      execute "DROP SEQUENCE IF EXISTS digital_dispute_submissions_new_id_seq;"
    end
  end
end
