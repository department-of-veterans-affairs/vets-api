# frozen_string_literal: true

# Representation of a submission to ClaimsEvidence API
# https://fwdproxy-dev.vfs.va.gov:4463/api/v1/rest/swagger-ui.html#/File/upload
#
# create_table "claims_evidence_api_submissions", force: :cascade do |t|
#   t.string "form_id", null: false, comment: "form type of the submission"
#   t.enum "latest_status", default: "pending", enum_type: "claims_evidence_api_submission_status"
#   t.string "va_claim_id", comment: "uuid returned from claims evidence api"
#   t.jsonb "reference_data_ciphertext", comment: "encrypted data that can be used to identify the resource"
#   t.text "encrypted_kms_key", comment: "KMS key used to encrypt the reference data"
#   t.boolean "needs_kms_rotation", default: false, null: false
#   t.integer "saved_claim_id", null: false, comment: "ID of the saved claim in vets-api"
#   t.integer "persistent_attachment_id", comment: "ID of the attachment in vets-api"
#   t.datetime "created_at", null: false
#   t.datetime "updated_at", null: false
#   t.index ["needs_kms_rotation"], name: "index_claims_evidence_api_submissions_on_needs_kms_rotation"
# end
class ClaimsEvidenceApi::Submission < Submission
  self.table_name = 'claims_evidence_api_submissions'

  include SubmissionEncryption

  has_many :submission_attempts, class_name: 'ClaimsEvidenceApi::SubmissionAttempt',
                                 foreign_key: :claims_evidence_api_submissions_id,
                                 dependent: :destroy, inverse_of: :submission
  belongs_to :saved_claim, optional: true

  alias_attribute :file_uuid, :va_claim_id

  # retrieve the header value from encrypted reference_data
  def x_folder_uri
    reference_data['x_folder_uri']
  end

  def x_folder_uri=(folder_identifier)
    folder_type, identifier_type, id = folder_identifier.split(':', 3)
    x_folder_uri_set(folder_type, identifier_type, id)
  end

  # the Folder identifier that the file will be associated to
  #   Header Format: folder-type:identifier-type:ID
  # Valid Folder-Types:
  # * VETERAN - Allows: FILENUMBER, SSN, PARTICIPANT_ID, SEARCH, ICN and EDIPI
  # * PERSON - Allows: PARTICIPANT_ID, SEARCH
  # eg. VETERAN:FILENUMBER:987267855
  def x_folder_uri_set(folder_type, identifier_type, id)
    # TODO: validate arguments

    data = reference_data || {}
    data['x_folder_uri'] = "#{type}:#{identifier}:#{id}"

    self.reference_data = data

    x_folder_uri
  end
end
