# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/constants'
require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_claims/utilities/helpers'

module V0
  class BenefitsClaimsController < ApplicationController
    before_action { authorize :lighthouse, :access? }
    service_tag 'claims-shared'

    def index
      claims = service.get_claims

      check_for_birls_id
      check_for_file_number

      claims['data'].each do |claim|
        update_claim_type_language(claim)
        # Add has_failed_uploads field for document uploads that were added
        if Flipper.enabled?(:cst_show_document_upload_status)
          claim['attributes']['hasFailedUploads'] = add_has_failed_uploads(claim)
        end
      end

      tap_claims(claims['data'])

      render json: claims
    end

    def show
      claim = service.get_claim(params[:id])
      update_claim_type_language(claim['data'])

      # Manual status override for certain tracked items
      # See https://github.com/department-of-veterans-affairs/va.gov-team/issues/101447
      # This should be removed when the items are re-categorized by BGS
      # We are not doing this in the Lighthouse service because we want web and mobile to have
      # separate rollouts and testing.
      claim = rename_rv1(claim) if Flipper.enabled?(:cst_override_reserve_records_website)

      # https://github.com/department-of-veterans-affairs/va.gov-team/issues/98364
      # This should be removed when the items are removed by BGS
      claim = suppress_evidence_requests(claim) if Flipper.enabled?(:cst_suppress_evidence_requests_website)

      # Document uploads to EVSS require a birls_id; This restriction should
      # be removed when we move to Lighthouse Benefits Documents for document uploads
      claim['data']['attributes']['canUpload'] = !@current_user.birls_id.nil?

      # Add Evidence Submissions section for document uploads that were added
      if Flipper.enabled?(:cst_show_document_upload_status)
        claim['data']['attributes']['evidenceSubmissions'] = add_evidence_submissions(claim['data'])
      end

      # We want to log some details about claim type patterns to track in DataDog
      log_claim_details(claim['data']['attributes'])

      tap_claims([claim['data']])

      render json: claim
    end

    def submit5103
      # Log if the user doesn't have a file number
      # NOTE: We are treating the BIRLS ID as a substitute
      # for file number here
      ::Rails.logger.info('[5103 Submission] No file number') if @current_user.birls_id.nil?

      json_payload = request.body.read

      data = JSON.parse(json_payload)

      tracked_item_id = data['trackedItemId'] || nil

      res = service.submit5103(params[:id], tracked_item_id)

      render json: res
    end

    private

    def claims_scope
      EVSSClaim.for_user(@current_user)
    end

    def service
      @service ||= BenefitsClaims::Service.new(@current_user.icn)
    end

    def check_for_birls_id
      ::Rails.logger.info('[BenefitsClaims#index] No birls id') if current_user.birls_id.nil?
    end

    def check_for_file_number
      bgs_file_number = BGS::People::Request.new.find_person_by_participant_id(user: current_user).file_number
      ::Rails.logger.info('[BenefitsClaims#index] No file number') if bgs_file_number.blank?
    end

    def tap_claims(claims)
      claims.each do |claim|
        record = claims_scope.where(evss_id: claim['id']).first

        if record.blank?
          EVSSClaim.create(
            user_uuid: @current_user.uuid,
            user_account: @current_user.user_account,
            evss_id: claim['id'],
            data: {}
          )
        else
          # If there is a record, we want to set the updated_at field
          # to Time.zone.now
          record.touch # rubocop:disable Rails/SkipsModelValidations
        end
      end
    end

    def update_claim_type_language(claim)
      language_map = BenefitsClaims::Constants::CLAIM_TYPE_LANGUAGE_MAP
      if language_map.key?(claim.dig('attributes', 'claimType'))
        claim['attributes']['claimType'] = language_map[claim['attributes']['claimType']]
      end
    end

    def add_has_failed_uploads(claim)
      failed_evidence_submissions = EvidenceSubmission.where(
        claim_id: claim['id'],
        upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]
      )
      failed_evidence_submissions.count.positive?
    end

    def add_evidence_submissions(claim)
      evidence_submissions = EvidenceSubmission.where(claim_id: claim['id'])
      tracked_items = claim['attributes']['trackedItems']

      filter_evidence_submissions(evidence_submissions, tracked_items)
    end

    def filter_evidence_submissions(evidence_submissions, tracked_items)
      filtered_evidence_submissions = []
      evidence_submissions.each do |es|
        filtered_evidence_submissions.push(build_filtered_evidence_submission_record(es, tracked_items))
      end

      filtered_evidence_submissions
    end

    def build_filtered_evidence_submission_record(evidence_submission, tracked_items)
      personalisation = JSON.parse(evidence_submission.template_metadata)['personalisation']
      tracked_item_display_name = BenefitsClaims::Utilities::Helpers.get_tracked_item_display_name(
        evidence_submission.tracked_item_id,
        tracked_items
      )

      { acknowledgement_date: evidence_submission.acknowledgement_date,
        claim_id: evidence_submission.claim_id,
        created_at: evidence_submission.created_at,
        delete_date: evidence_submission.delete_date,
        document_type: personalisation['document_type'],
        failed_date: evidence_submission.failed_date,
        file_name: personalisation['file_name'],
        id: evidence_submission.id,
        lighthouse_upload: evidence_submission.job_class == 'Lighthouse::EvidenceSubmissions::DocumentUpload',
        tracked_item_id: evidence_submission.tracked_item_id,
        tracked_item_display_name:,
        upload_status: evidence_submission.upload_status,
        va_notify_status: evidence_submission.va_notify_status }
    end

    def log_claim_details(claim_info)
      ::Rails.logger.info('Claim Type Details',
                          { message_type: 'lh.cst.claim_types',
                            claim_type: claim_info['claimType'],
                            claim_type_code: claim_info['claimTypeCode'],
                            num_contentions: claim_info['contentions'].count,
                            ep_code: claim_info['endProductCode'],
                            current_phase_back: claim_info['claimPhaseDates']['currentPhaseBack'],
                            latest_phase_type: claim_info['claimPhaseDates']['latestPhaseType'],
                            decision_letter_sent: claim_info['decisionLetterSent'],
                            development_letter_sent: claim_info['developmentLetterSent'],
                            claim_id: params[:id] })
      log_evidence_requests(params[:id], claim_info)
    end

    def log_evidence_requests(claim_id, claim_info)
      tracked_items = claim_info['trackedItems']

      tracked_items.each do |ti|
        ::Rails.logger.info('Evidence Request Types',
                            { message_type: 'lh.cst.evidence_requests',
                              claim_id:,
                              tracked_item_id: ti['id'],
                              tracked_item_type: ti['displayName'],
                              tracked_item_status: ti['status'] })
      end
    end

    def rename_rv1(claim)
      tracked_items = claim.dig('data', 'attributes', 'trackedItems')
      tracked_items&.select { |i| i['displayName'] == 'RV1 - Reserve Records Request' }&.each do |i|
        i['status'] = 'NEEDED_FROM_OTHERS'
      end
      claim
    end

    def suppress_evidence_requests(claim)
      tracked_items = claim.dig('data', 'attributes', 'trackedItems')
      return unless tracked_items

      tracked_items.reject! { |i| BenefitsClaims::Service::SUPPRESSED_EVIDENCE_REQUESTS.include?(i['displayName']) }
      claim
    end
  end
end
