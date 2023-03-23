# frozen_string_literal: true

require 'claims_api/vbms_uploader'

module ClaimsApi
  module EwsVBMSSidekiq
    include SentryLogging

    def upload_to_vbms(evidence_waiver_submission, path)
      uploader = VBMSUploader.new(
        filepath: path,
        file_number: retrieve_veteran_file_number(evidence_waiver_submission:),
        doc_type: '705'
      )
      uploader.upload!
      evidence_waiver_submission.update(
        status: ClaimsApi::EvidenceWaiverSubmission::UPLOADED
      )
    end

    def rescue_file_not_found(evidence_waiver_submission)
      evidence_waiver_submission.update(
        status: ClaimsApi::EvidenceWaiverSubmission::ERRORED,
        vbms_error_message: 'File could not be retrieved from AWS'
      )
    end

    def rescue_vbms_error(evidence_waiver_submission)
      evidence_waiver_submission.vbms_upload_failure_count = evidence_waiver_submission.vbms_upload_failure_count + 1
      evidence_waiver_submission.vbms_error_message = 'An unknown error has occurred when uploading document'
      if evidence_waiver_submission.vbms_upload_failure_count < 5
        self.class.perform_in(30.minutes, evidence_waiver_submission.id)
      else
        evidence_waiver_submission.status = ClaimsApi::EvidenceWaiverSubmission::ERRORED
      end
      evidence_waiver_submission.save
    end

    def rescue_vbms_file_number_not_found(evidence_waiver_submission)
      error_message = 'VBMS is unable to locate file number'
      evidence_waiver_submission.update(
        status: ClaimsApi::EvidenceWaiverSubmission::ERRORED,
        vbms_error_message: error_message
      )
      log_message_to_sentry(self.class.name, :warning, body: error_message)
    end

    private

    def retrieve_veteran_file_number(evidence_waiver_submission:)
      ssn = evidence_waiver_submission.auth_headers['va_eauth_pnid']

      begin
        bgs_service(evidence_waiver_submission:).people.find_by_ssn(ssn)&.[](:file_nbr) # rubocop:disable Rails/DynamicFindBy
      rescue BGS::ShareError => e
        error_message = "A BGS failure occurred while trying to retrieve Veteran 'FileNumber'"
        log_exception_to_sentry(e, nil, { message: error_message }, 'warn')
        raise ::Common::Exceptions::FailedDependency
      end
    end

    def bgs_service(evidence_waiver_submission:)
      BGS::Services.new(
        external_uid: evidence_waiver_submission.auth_headers['va_eauth_pid'],
        external_key: evidence_waiver_submission.auth_headers['va_eauth_pid']
      )
    end
  end
end
