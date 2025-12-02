# frozen_string_literal: true

class SwapDigitalDisputeSubmissionsIdColumns < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      drop_uuid_primary_key
      swap_columns
      setup_bigint_primary_key
    end
  end

  def down
    safety_assured do
      # Drop current PK
      execute 'ALTER TABLE digital_dispute_submissions DROP CONSTRAINT IF EXISTS digital_dispute_submissions_pkey;'

      # Swap back
      rename_column :digital_dispute_submissions, :id, :new_id
      rename_column :digital_dispute_submissions, :old_uuid_id, :id

      # Restore PK on UUID `id`
      execute 'ALTER TABLE digital_dispute_submissions ADD PRIMARY KEY (id);'

      # Restore UUID default
      execute 'ALTER TABLE digital_dispute_submissions ALTER COLUMN id SET DEFAULT gen_random_uuid();'
    end
  end

  private

  def drop_uuid_primary_key
    execute <<~SQL
      ALTER TABLE digital_dispute_submissions
      DROP CONSTRAINT IF EXISTS digital_dispute_submissions_pkey;
    SQL
  end

  def swap_columns
    rename_column :digital_dispute_submissions, :id, :old_uuid_id
    rename_column :digital_dispute_submissions, :new_id, :id
  end

  def setup_bigint_primary_key
    # Add new PK
    execute 'ALTER TABLE digital_dispute_submissions ADD PRIMARY KEY (id);'

    # Dynamically fetch the sequence name for "id"
    seq = select_value <<~SQL
      SELECT pg_get_serial_sequence('digital_dispute_submissions', 'id');
    SQL

    # Apply default + ownership
    execute "ALTER TABLE digital_dispute_submissions ALTER COLUMN id SET DEFAULT nextval('#{seq}');"
    execute "ALTER SEQUENCE #{seq} OWNED BY digital_dispute_submissions.id;"
  end
end
