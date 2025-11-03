# frozen_string_literal: true

require 'claims_evidence_api/monitor'
require 'claims_evidence_api/folder_identifier'

# Representation of a submission to ClaimsEvidence API
# https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/File/upload
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
  belongs_to :persistent_attachment, optional: true

  alias_attribute :file_uuid, :va_claim_id

  before_validation { self.form_id ||= saved_claim&.form_id }

  after_create { monitor.track_event(:create, **tracking_attributes) }
  after_destroy { monitor.track_event(:destroy, **tracking_attributes) }

  # @see ClaimsEvidenceApi::Monitor::Record
  def monitor
    @monitor ||= ClaimsEvidenceApi::Monitor::Record.new(self)
  end

  # utility function to acquire the tracking attributes for _this_ record
  def tracking_attributes
    { id:, file_uuid:, form_id:, saved_claim_id:, persistent_attachment_id:, doctype: }
  end

  # retrieve the document_type of the associated evidence [PersistentAttachment|SavedClaim]
  def document_type
    persistent_attachment&.document_type || saved_claim&.document_type
  end
  alias doctype document_type

  # insert values into the reference data field
  # unnamed values will overwrite the reference_data['__'] array
  def update_reference_data(*args, **kwargs)
    self.reference_data ||= {}
    self.reference_data.merge!(kwargs.except(:folder_identifier, :x_folder_uri).deep_stringify_keys)
    self.reference_data['__'] = args

    # ensure folder identifier value is checked and appended
    %i[folder_identifier x_folder_uri].each do |fid_key|
      self.folder_identifier = kwargs[fid_key] if kwargs[fid_key].present?
    end

    self.reference_data
  end

  # retrieve the latest folder identifier from encrypted reference_data
  def folder_identifier
    self.reference_data ||= {}
    self.reference_data['latest_folder_identifier']
  end

  # directly assign a folder identifier; value is split and sent through #folder_identifier_set
  #
  # @param folder_identifier [String] x_folder_uri header value
  def folder_identifier=(folder_identifier)
    folder_type, identifier_type, id = folder_identifier.split(':', 3)
    folder_identifier_set(folder_type, identifier_type, id)
  end

  # set the folder identifier that the file will be associated to
  # @see ClaimsEvidenceApi::FolderIdentifier#generate
  def folder_identifier_set(folder_type, identifier_type, id)
    self.reference_data ||= {}
    fids = reference_data['folder_identifier'] || []
    fid = ClaimsEvidenceApi::FolderIdentifier.generate(folder_type, identifier_type, id)
    fids << fid unless fids.include?(fid)

    self.reference_data['folder_identifier'] = fids
    self.reference_data['latest_folder_identifier'] = fid

    folder_identifier
  end
end
