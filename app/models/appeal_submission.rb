# frozen_string_literal: true

require 'decision_review/utilities/saved_claim/service'

class AppealSubmission < ApplicationRecord
  include DecisionReview::SavedClaim::Service

  APPEAL_TYPES = %w[HLR NOD SC].freeze
  validates :user_uuid, :submitted_appeal_uuid, presence: true
  belongs_to :user_account, dependent: nil, optional: true
  validates :type_of_appeal, inclusion: APPEAL_TYPES

  has_kms_key
  has_encrypted :upload_metadata, key: :kms_key, **lockbox_options

  has_many :appeal_submission_uploads, dependent: :destroy

  scope :failure_not_sent, -> { where(failure_notification_sent_at: nil).order(id: :asc) }

  def self.submit_nod(request_body_hash:, current_user:, decision_review_service: nil)
    ActiveRecord::Base.transaction do
      raise 'Must pass in a version of the DecisionReview Service' if decision_review_service.nil?

      appeal_submission = new(type_of_appeal: 'NOD',
                              user_uuid: current_user.uuid,
                              user_account: current_user.user_account,
                              board_review_option: request_body_hash['data']['attributes']['boardReviewOption'],
                              upload_metadata: decision_review_service.class.file_upload_metadata(current_user))

      form = request_body_hash.to_json # serialize before modifications are made to request body
      uploads_arr = request_body_hash.delete('nodUploads') || []
      nod_response_body = decision_review_service.create_notice_of_disagreement(request_body: request_body_hash,
                                                                                user: current_user)
                                                 .body

      guid = nod_response_body.dig('data', 'id')
      appeal_submission.submitted_appeal_uuid = guid
      appeal_submission.save!

      appeal_submission.store_saved_claim(claim_class: SavedClaim::NoticeOfDisagreement, form:, guid:)

      # Clear in-progress form if submit was successful
      InProgressForm.form_for_user('10182', current_user)&.destroy!

      appeal_submission.enqueue_uploads(uploads_arr, current_user)
      nod_response_body
    end
  end

  def enqueue_uploads(uploads_arr, _user)
    uploads_arr.each do |upload_attrs|
      asu = AppealSubmissionUpload.create!(decision_review_evidence_attachment_guid: upload_attrs['confirmationCode'],
                                           appeal_submission_id: id)
      DecisionReview::SubmitUpload.perform_async(asu.id)
    end
  end

  def current_email
    va_profile = ::VAProfile::ContactInformation::Service.get_person(get_mpi_profile.vet360_id.to_s)&.person
    raise 'Failed to fetch VA profile' if va_profile.nil?

    current_emails = va_profile.emails.select { |email| email.effective_end_date.nil? }
    email = current_emails.first&.email_address
    raise 'Failed to retrieve email' if email.nil?

    email
  end

  def get_mpi_profile
    @mpi_profile ||= begin
      service = ::MPI::Service.new
      idme_profile = service.find_profile_by_identifier(identifier: user_uuid, identifier_type: 'idme')&.profile
      logingov_profile = service.find_profile_by_identifier(identifier: user_uuid, identifier_type: 'logingov')&.profile
      response = idme_profile || logingov_profile
      raise 'Failed to fetch MPI profile' if response.nil?

      response
    end
  end
end
