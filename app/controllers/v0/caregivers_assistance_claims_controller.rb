# frozen_string_literal: true

module V0
  # Application for the Program of Comprehensive Assistance for Family Caregivers (Form 10-10CG)
  class CaregiversAssistanceClaimsController < ApplicationController
    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token, only: :emis_test

    rescue_from ::Form1010cg::Service::InvalidVeteranStatus, with: :backend_service_outage

    def emis_test
      claim_data = VetsJsonSchema::EXAMPLES['10-10CG'].clone.deep_merge('veteran' => veteran_data_params.to_h)

      vet_icn = ::Form1010cg::Service.new(
        SavedClaim::CaregiversAssistanceClaim.new(form: claim_data.to_json)
      ).icn_for('veteran')

      emis_response = EMIS::VeteranStatusService.new.get_veteran_status(icn: vet_icn) unless vet_icn == 'NOT_FOUND'

      render json: {
        icn: vet_icn,
        emis: emis_response&.items&.first,
        is_veteran: emis_response&.items&.first&.title38_status_code == 'V1',
        claim_data: claim_data
      }
    end

    def create
      increment Form1010cg::Service.metrics.submission.attempt
      return service_unavailable unless Flipper.enabled?(:allow_online_10_10cg_submissions)

      claim = SavedClaim::CaregiversAssistanceClaim.new(form: form_submission)

      if claim.valid?
        submission = ::Form1010cg::Service.new(claim).process_claim!
        increment Form1010cg::Service.metrics.submission.success
        render json: submission, serializer: ::Form1010cg::SubmissionSerializer
      else
        increment Form1010cg::Service.metrics.submission.failure.client.data
        raise(Common::Exceptions::ValidationErrors, claim)
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

        claim.to_pdf(uuid)

        source_file_path = Rails.root.join 'tmp', 'pdfs', "10-10CG_#{uuid}.pdf"
        client_file_name = file_name_for_pdf(claim.veteran_data)
        file_contents    = File.read(source_file_path)

        File.delete(source_file_path)

        increment Form1010cg::Service.metrics.pdf_download

        send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
      else
        raise(Common::Exceptions::ValidationErrors, claim)
      end
    end

    private

    def veteran_data_params
      params.require(:veteran).permit(:ssnOrTin, :dateOfBirth, :gender, fullName: %i[first middle last])
    end

    def file_name_for_pdf(veteran_data)
      "10-10CG_#{veteran_data['fullName']['first']}_#{veteran_data['fullName']['last']}.pdf"
    end

    def form_submission
      params.require(:caregivers_assistance_claim).require(:form)
    rescue
      increment Form1010cg::Service.metrics.submission.failure.client.data
      raise
    end

    def service_unavailable
      render nothing: true, status: :service_unavailable, as: :json
    end

    def backend_service_outage
      increment Form1010cg::Service.metrics.submission.failure.client.qualification
      render_errors Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
    end

    def increment(stat)
      StatsD.increment stat
    end
  end
end
