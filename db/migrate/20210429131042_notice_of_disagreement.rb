# frozen_string_literal: true

class NoticeOfDisagreement < ActiveRecord::Migration[6.0]
  def change
    # column is not yet used so it's safe to rename
    safety_assured { remove_column :appeal_submissions, :board_review_otpion, :string }
    add_column :appeal_submissions, :board_review_option, :string
    add_column :appeal_submissions, :encrypted_upload_metadata, :string
    add_column :appeal_submissions, :encrypted_upload_metadata_iv, :string

    create_table(:appeal_submission_uploads) do |t|
      t.string :decision_review_evidence_attachment_guid
      t.string :appeal_submission_id
      t.string :lighthouse_upload_id
      t.timestamps
    end
  end
end
