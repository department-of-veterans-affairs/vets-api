# frozen_string_literal: true

require 'claims_api/vbms_uploader'

module ClaimsApi
  module EwsVBMSSidekiq
    include SentryLogging

    def upload_to_vbms(evidence_waiver_submission, path)
      uploader = ClaimsApi::VBMSUploader.new(
        filepath: path,
        file_number: evidence_waiver_submission.auth_headers['va_eauth_birlsfilenumber'],
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

    def rescue_invalid_filename(evidence_waiver_submission, error)
      if invalid_format_error_response(error)
        evidence_waiver_submission.update(
          status: ClaimsApi::EvidenceWaiverSubmission::ERRORED,
          vbms_error_message: 'Invalid format for veteran identifier'
        )
      end
    end

    def invalid_format_error_response(error)
      # Parse error response from VBMS to determine if it should be retried
      if error.instance_of?(VBMS::HTTPError) && (error.message.is_a? String)
        start = error.message.index('<env:Envelope')
        finish = error.message.index('</env:Envelope')
        soap_message = error.message[start..finish - 1]

        doc = Nokogiri::XML.parse soap_message
        detail = doc.at_xpath('//env:Envelope/env:Body/env:Fault/detail')
        fault_message = detail.xpath('.//efc:message',
                                     { 'efc' => 'http://service.efolder.vbms.vba.va.gov/common' }).text
        fault_message == 'Invalid format for Veteran Identifier.'
      else
        false
      end
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
  end
end
