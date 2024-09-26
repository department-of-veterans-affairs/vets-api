# frozen_string_literal: true

require 'lighthouse/facilities/v1/client'
module V0
  # Application for the Program of Comprehensive Assistance for Family Caregivers (Form 10-10CG)
  class CaregiversAssistanceClaimsController < ApplicationController
    service_tag 'caregiver-application'

    AUDITOR = ::Form1010cg::Auditor.new

    skip_before_action :authenticate
    before_action :load_user, only: :create

    before_action :record_submission_attempt, only: :create
    before_action :initialize_claim, only: %i[create download_pdf]

    rescue_from ::Form1010cg::Service::InvalidVeteranStatus, with: :backend_service_outage

    def create
      if @claim.valid?
        Sentry.set_tags(claim_guid: @claim.guid)
        auditor.record_caregivers(@claim)

        ::Form1010cg::Service.new(@claim).assert_veteran_status

        @claim.save!
        ::Form1010cg::SubmissionJob.perform_async(@claim.id)
        render json: ::Form1010cg::ClaimSerializer.new(@claim)
      else
        PersonalInformationLog.create!(data: { form: @claim.parsed_form }, error_class: '1010CGValidationError')
        auditor.record(:submission_failure_client_data, claim_guid: @claim.guid, errors: @claim.errors.messages)
        raise(Common::Exceptions::ValidationErrors, @claim)
      end
    end

    # If we were unable to submit the user's claim digitally, we allow them to the download
    # the 10-10CG PDF, pre-filled with their data, for them to mail in.
    def download_pdf
      # Brakeman will raise a warning if we use a claim's method or attribute in the source file name.
      # Use an arbitrary uuid for the source file name and don't use the return value of claim#to_pdf
      # as the source_file_path (to prevent changes in the the filename creating a vunerability in the future).
      source_file_path = PdfFill::Filler.fill_form(@claim, SecureRandom.uuid, sign: false)
      client_file_name = file_name_for_pdf(@claim.veteran_data)
      file_contents    = File.read(source_file_path)

      # rubocop:disable Lint/NonAtomicFileOperation
      File.delete(source_file_path) if File.exist?(source_file_path)
      # rubocop:enable Lint/NonAtomicFileOperation

      auditor.record(:pdf_download)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    end

    def facilities
      lighthouse_facilities = lighthouse_facilities_service.get_paginated_facilities(lighthouse_facilities_params)
      render(json: lighthouse_facilities)
    end

    private

    def lighthouse_facilities_service
      @lighthouse_facilities_service ||= Lighthouse::Facilities::V1::Client.new
    end

    def lighthouse_facilities_params
      params.permit(
        :zip,
        :state,
        :lat,
        :long,
        :radius,
        :visn,
        :type,
        :mobile,
        :page,
        :per_page,
        :facilityIds,
        services: [],
        bbox: []
      )
    end

    def record_submission_attempt
      auditor.record(:submission_attempt)
    end

    def form_submission
      params.require(:caregivers_assistance_claim).require(:form)
    rescue => e
      auditor.record(:submission_failure_client_data, errors: [e.original_message])
      raise e
    end

    def initialize_claim
      @claim = SavedClaim::CaregiversAssistanceClaim.new(form: form_submission)
    end

    def file_name_for_pdf(veteran_data)
      veteran_name = veteran_data.try(:[], 'fullName')
      first_name = veteran_name.try(:[], 'first') || 'First'
      last_name = veteran_name.try(:[], 'last') || 'Last'
      "10-10CG_#{first_name}_#{last_name}.pdf"
    end

    def backend_service_outage
      auditor.record(
        :submission_failure_client_qualification,
        claim_guid: @claim.guid
      )

      render_errors Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
    end

    def auditor
      self.class::AUDITOR
    end
  end
end
