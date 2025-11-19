# frozen_string_literal: true

class ChangeDigitalDisputeSubmissionsIdToBigint < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      # Create new bigint id column which will become new primary key
      execute 'ALTER TABLE digital_dispute_submissions ADD COLUMN id_new BIGSERIAL'

      # Delete invalid attachments
      execute "DELETE FROM active_storage_attachments WHERE record_type = 'DebtsApi::V0::DigitalDisputeSubmission'"

      # Drop old primary key, swap in new int ID, rename
      execute 'ALTER TABLE digital_dispute_submissions DROP CONSTRAINT digital_dispute_submissions_pkey CASCADE'
      remove_column :digital_dispute_submissions, :id
      rename_column :digital_dispute_submissions, :id_new, :id
      execute 'ALTER SEQUENCE digital_dispute_submissions_id_new_seq1 RENAME TO digital_dispute_submissions_id_seq'
      execute 'ALTER TABLE digital_dispute_submissions ADD PRIMARY KEY (id)'
    end

    # Add new colum for storing public facing UUIDs
    add_column :digital_dispute_submissions, :guid, :uuid
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
