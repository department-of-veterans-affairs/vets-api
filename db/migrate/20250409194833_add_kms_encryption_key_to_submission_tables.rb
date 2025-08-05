class AddKmsEncryptionKeyToSubmissionTables < ActiveRecord::Migration[7.2]
  def change
    add_column :bpds_submissions, :encrypted_kms_key, :text, comment: 'KMS key used to encrypt the reference data'
    add_column :bpds_submission_attempts, :encrypted_kms_key, :text, comment: 'KMS key used to encrypt sensitive data'
    add_column :lighthouse_submissions, :encrypted_kms_key, :text, comment: 'KMS key used to encrypt the reference data'
    add_column :lighthouse_submission_attempts, :encrypted_kms_key, :text, comment: 'KMS key used to encrypt sensitive data'
  end
end
