class EvidenceWaiverSubmission < ActiveRecord::Migration[6.1]
  def change
    create_table :claims_api_evidence_waiver_submissions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.text :auth_headers_ciphertext
      t.text :encrypted_kms_key
      t.string :cid

      t.timestamps
    end
  end
end