# frozen_string_literal: true

class SwapDigitalDisputeSubmissionsIdColumns < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      drop_uuid_primary_key
      swap_columns
      setup_bigint_primary_key
    end
  end

  private

  def drop_uuid_primary_key
    execute 'ALTER TABLE digital_dispute_submissions DROP CONSTRAINT digital_dispute_submissions_pkey;'
  end

  def swap_columns
    rename_column :digital_dispute_submissions, :id, :old_uuid_id
    rename_column :digital_dispute_submissions, :new_id, :id
  end

  def setup_bigint_primary_key
    execute 'ALTER TABLE digital_dispute_submissions ADD PRIMARY KEY (id);'
    execute 'ALTER TABLE digital_dispute_submissions ALTER COLUMN id SET NOT NULL;'
    execute <<-SQL.squish
      ALTER TABLE digital_dispute_submissions
      ALTER COLUMN id SET DEFAULT nextval('digital_dispute_submissions_new_id_seq');
    SQL
    execute 'ALTER SEQUENCE digital_dispute_submissions_new_id_seq OWNED BY digital_dispute_submissions.id;'
  end
end
