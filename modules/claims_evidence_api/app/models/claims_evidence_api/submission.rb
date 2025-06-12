# frozen_string_literal: true

class ClaimsEvidenceApi::Submission < Submission
  self.table_name = 'claims_evidence_api_submissions'

  include SubmissionEncryption

  has_many :submission_attempts, class_name: 'ClaimsEvidenceApi::SubmissionAttempt', foreign_key: :claims_evidence_api_submissions_id,
                                 dependent: :destroy, inverse_of: :submission
  belongs_to :saved_claim, optional: true

  alias_attribute :file_uuid, :va_claim_id

  def x_folder_uri?
    reference_data['x_folder_uri']
  end

  # the Folder identifier that the file will be associated to
  # Header Format: folder-type:identifier-type:ID
  # Valid Folder-Types:
  # * VETERAN - Allows: FILENUMBER, SSN, PARTICIPANT_ID, SEARCH, ICN and EDIPI
  # * PERSON - Allows: PARTICIPANT_ID, SEARCH
  # eg. VETERAN:FILENUMBER:987267855
  def x_folder_uri(type, identifier, id)
    # TODO: validate arguments

    data = reference_data || {}
    data['x_folder_uri'] = "#{type}:#{identifier}:#{id}"

    self.reference_data = data

    x_folder_uri?
  end
end
