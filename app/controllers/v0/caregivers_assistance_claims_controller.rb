# frozen_string_literal: true

module V0
  # Application for the Program of Comprehensive Assistance for Family Caregivers (Form 10-10CG)
  class CaregiversAssistanceClaimsController < ApplicationController
    skip_before_action :authenticate

    rescue_from ::Form1010cg::Service::InvalidVeteranStatus, with: :backend_service_outage

    AUDITOR = Form1010cg::Auditor.new

    def create
      auditor.record(:submission_attempt)

      @claim = SavedClaim::CaregiversAssistanceClaim.new(form: form_submission)

      if @claim.valid?
        submission = ::Form1010cg::Service.new(@claim).process_claim!
        record_submission_success submission
        render json: submission, serializer: ::Form1010cg::SubmissionSerializer
      else
        auditor.record(:submission_failure_client_data, claim_guid: @claim.guid, errors: @claim.errors.messages)
        raise(Common::Exceptions::ValidationErrors, @claim)
      end
    end

    # If we were unable to submit the user's claim digitally, we allow them to the download
    # the 10-10CG PDF, pre-filled with their data, for them to mail in.
    def download_pdf
      claim = SavedClaim::CaregiversAssistanceClaim.new(form: form_submission)

      if claim.valid?
        # Brakeman will raise a warning if we use a claim's method or attribute in the source file name.
        # Use an arbitrary uuid for the source file name and don't use the return value of claim#to_pdf
        # as the source_file_path (to prevent changes in the the filename creating a vunerability in the future).
        uuid = SecureRandom.uuid

        claim.to_pdf(uuid, sign: false)

        source_file_path = Rails.root.join 'tmp', 'pdfs', "10-10CG_#{uuid}.pdf"
        client_file_name = file_name_for_pdf(claim.veteran_data)
        file_contents    = File.read(source_file_path)

        File.delete(source_file_path)

        auditor.record(:pdf_download)

        send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
      else
        raise(Common::Exceptions::ValidationErrors, claim)
      end
    end

    private

    def file_name_for_pdf(veteran_data)
      "10-10CG_#{veteran_data['fullName']['first']}_#{veteran_data['fullName']['last']}.pdf"
    end

    def form_submission
      params.require(:caregivers_assistance_claim).require(:form)
    rescue => e
      auditor.record(:submission_failure_client_data, errors: [e.message])
      raise e
    end

    def backend_service_outage
      auditor.record(
        :submission_failure_client_qualification,
        claim_guid: @claim.guid
      )

      render_errors Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
    end

    def record_submission_success(submission)
      submission_context = {
        carma_case_id: submission.carma_case_id,
        metadata: submission.metadata,
        attachments: submission.attachments,
        attachments_job_id: submission.attachments_job_id
      }

      auditor.record(:submission_success, claim_guid: @claim.guid, **submission_context)
    end

    def auditor
      self.class::AUDITOR
    end
  end
end
