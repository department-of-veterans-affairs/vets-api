# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module V0
  class BenefitsClaimsController < ApplicationController
    before_action { authorize :lighthouse, :access? }
    service_tag 'claims-shared'

    def index
      claims = service.get_claims

      check_for_birls_id
      check_for_file_number

      tap_claims(claims['data'])

      render json: claims
    end

    def show
      claim = service.get_claim(params[:id])

      # Document uploads to EVSS require a birls_id; This restriction should
      # be removed when we move to Lighthouse Benefits Documents for document uploads
      claim['data']['attributes']['canUpload'] = !@current_user.birls_id.nil?

      # We want to log some details about claim type patterns to track in DataDog
      claim_info = claim['data']['attributes']
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
  end
end
