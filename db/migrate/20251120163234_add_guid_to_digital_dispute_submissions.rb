# frozen_string_literal: true

class AddGuidToDigitalDisputeSubmissions < ActiveRecord::Migration[7.2]
  def up
    add_column :digital_dispute_submissions, :guid, :uuid
    change_column_default :digital_dispute_submissions, :guid, from: nil, to: -> { 'gen_random_uuid()' }

    # Backfill existing records with guids
    # rubocop:disable Rails/SkipsModelValidations
    DebtsApi::V0::DigitalDisputeSubmission.where(guid: nil).update_all('guid = gen_random_uuid()')
    # rubocop:enable Rails/SkipsModelValidations

    safety_assured do
      change_column_null :digital_dispute_submissions, :guid, false
    end
  end

  def down
    safety_assured do
      change_column_null :digital_dispute_submissions, :guid, true
    end
    change_column_default :digital_dispute_submissions, :guid, from: -> { 'gen_random_uuid()' }, to: nil
    remove_column :digital_dispute_submissions, :guid
  end
end
