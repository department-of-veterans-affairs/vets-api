# frozen_string_literal: true

require 'claims_evidence_api/monitor'

# Representation of a submission attempt to ClaimsEvidence API
# https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html#model-payload
#
# create_table "claims_evidence_api_submission_attempts", force: :cascade do |t|
#   t.bigint "claims_evidence_api_submissions_id", null: false
#   t.enum "status", default: "pending", enum_type: "claims_evidence_api_submission_status"
#   t.jsonb "metadata_ciphertext", comment: "encrypted metadata sent with the submission"
#   t.jsonb "error_message_ciphertext", comment: "encrypted error message from the claims evidence api submission"
#   t.jsonb "response_ciphertext", comment: "encrypted response from the claims evidence api submission"
#   t.text "encrypted_kms_key", comment: "KMS key used to encrypt the reference data"
#   t.boolean "needs_kms_rotation", default: false, null: false
#   t.datetime "created_at", null: false
#   t.datetime "updated_at", null: false
#   t.index ["claims_evidence_api_submissions_id"], name: "idx_on_claims_evidence_api_submissions_id_40971596ee"
#   t.index ["needs_kms_rotation"], name: "idx_on_needs_kms_rotation_516b2a537c"
# end
class ClaimsEvidenceApi::SubmissionAttempt < SubmissionAttempt
  self.table_name = 'claims_evidence_api_submission_attempts'

  include SubmissionAttemptEncryption

  belongs_to :submission, class_name: 'ClaimsEvidenceApi::Submission',
                          foreign_key: :claims_evidence_api_submissions_id,
                          inverse_of: :submission_attempts
  has_one :saved_claim, through: :submission

  after_create { monitor.track_event(:create, **tracking_attributes) }
  after_update { monitor.track_event(:update, **tracking_attributes) }
  after_destroy { monitor.track_event(:destroy, **tracking_attributes) }

  # @see ClaimsEvidenceApi::Monitor::Record
  def monitor
    @monitor ||= ClaimsEvidenceApi::Monitor::Record.new(self)
  end

  # utility function to acquire the tracking attributes for _this_ record
  def tracking_attributes
    { id:, status:, submission_id: submission.id, saved_claim_id: saved_claim&.id, form_id: saved_claim&.form_id }
  end
end
