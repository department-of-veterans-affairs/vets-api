# frozen_string_literal: true

class SwapDigitalDisputeSubmissionsIdColumns < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      # Drop PK
      execute <<~SQL
        ALTER TABLE digital_dispute_submissions
        DROP CONSTRAINT IF EXISTS digital_dispute_submissions_pkey;
      SQL

      # Swap columns
      rename_column :digital_dispute_submissions, :id, :old_uuid_id
      rename_column :digital_dispute_submissions, :new_id, :id

      # Add PK on bigint id
      execute "ALTER TABLE digital_dispute_submissions ADD PRIMARY KEY (id);"

      # Fetch correct sequence
      seq = select_value(<<~SQL)
        SELECT pg_get_serial_sequence('digital_dispute_submissions', 'id');
      SQL

      # Attach sequence + default
      execute "ALTER TABLE digital_dispute_submissions ALTER COLUMN id SET DEFAULT nextval('#{seq}');"
      execute "ALTER SEQUENCE #{seq} OWNED BY digital_dispute_submissions.id;"
    end
  end

  def down
    safety_assured do
      execute <<~SQL
        ALTER TABLE digital_dispute_submissions
        DROP CONSTRAINT IF EXISTS digital_dispute_submissions_pkey;
      SQL

      rename_column :digital_dispute_submissions, :id, :new_id
      rename_column :digital_dispute_submissions, :old_uuid_id, :id

      # Restore PK on uuid
      execute "ALTER TABLE digital_dispute_submissions ADD PRIMARY KEY (id);"

      # Restore UUID generation default
      execute "ALTER TABLE digital_dispute_submissions ALTER COLUMN id SET DEFAULT gen_random_uuid();"
    end
  end
end