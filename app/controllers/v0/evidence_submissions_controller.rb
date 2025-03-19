# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'
require 'lighthouse/benefits_claims/utilities/helpers'
module V0
  class EvidenceSubmissionsController < ApplicationController
    service_tag 'claims-shared'

    def index
      render json: { data: filter_evidence_submissions }
    end

    private

    def failed_evidence_submissions
      @failed_evidence_submissions ||= EvidenceSubmission.failed.where(user_account: current_user_account.id)
    end

    def current_user_account
      UserAccount.find(@current_user.user_account_uuid)
    end

    def benefits_claims_service
      BenefitsClaims::Service.new(@current_user.icn)
    end

    def filter_evidence_submissions
      filtered_evidence_submissions = []
      claims = {}
      failed_evidence_submissions.each do |es|
        # When we get a claim we add it to claims so that we prevent calling lighthouse multiple times
        # to get the same claim.
        claim = claims[es.claim_id]
        if claim.nil?
          claim = benefits_claims_service.get_claim(es.claim_id)
          claims[es.claim_id] = claim
        end
        tracked_items = claim['data']['attributes']['trackedItems']
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
        document_type: personalisation['document_type'],
        failed_date: evidence_submission.failed_date,
        file_name: personalisation['file_name'],
        id: evidence_submission.id,
        tracked_item_id: evidence_submission.tracked_item_id,
        tracked_item_display_name: }
    end
  end
end
