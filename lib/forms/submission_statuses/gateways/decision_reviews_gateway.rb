# frozen_string_literal: true

require 'decision_reviews/v1/service'
require 'lighthouse/benefits_intake/service'
require_relative '../dataset'
require_relative '../error_handler'
require_relative 'base_gateway'

module Forms
  module SubmissionStatuses
    module Gateways
      class DecisionReviewsGateway < BaseGateway
        def submissions
          appeal_uuids = user_appeal_uuids
          query = base_saved_claim_query(appeal_uuids)
          query = filter_by_allowed_forms(query) if @allowed_forms.present?
          query.order(created_at: :asc).to_a
        end

        def api_statuses(submissions)
          statuses_data = []
          errors = []

          submissions.each do |submission|
            process_submission(submission, statuses_data, errors)
          end

          [statuses_data, errors.any? ? errors : nil]
        end

        private

        # Normalize Decision Reviews API statuses to frontend-supported statuses
        # Frontend maps 'vbms' -> 'received', 'error' and 'expired' -> 'actionNeeded',
        # and everything else to 'inProgress', so we only need to map 'complete'
        # to 'vbms' to indicate form was successfully received
        def normalize_status(api_status)
          api_status&.downcase == 'complete' ? 'vbms' : api_status
        end

        def get_secondary_form_statuses(submission)
          secondary_statuses = []
          return secondary_statuses unless secondary_forms?(submission)

          submission.appeal_submission.secondary_appeal_forms.each do |secondary_form|
            process_secondary_form(secondary_form, secondary_statuses)
          end

          secondary_statuses
        end

        def secondary_forms?(submission)
          submission.appeal_submission&.secondary_appeal_forms&.any?
        end

        def process_secondary_form(secondary_form, secondary_statuses)
          response = benefits_intake_service.get_status(uuid: secondary_form.guid)
          attributes = response.body.dig('data', 'attributes')
          status_record = build_secondary_status_record(secondary_form, attributes)
          secondary_statuses << status_record
        rescue Common::Exceptions::BackendServiceException => e
          log_secondary_form_error(secondary_form, e)
        end

        def build_secondary_status_record(secondary_form, attributes)
          {
            'id' => secondary_form.guid,
            'attributes' => {
              'guid' => secondary_form.guid,
              'status' => attributes['status'],
              'detail' => attributes['detail'],
              'message' => attributes['status'],
              'created_at' => secondary_form.created_at,
              'updated_at' => attributes['updated_at'],
              'form_type' => 'form0995_form4142'
            }
          }
        end

        def log_secondary_form_error(secondary_form, error)
          Rails.logger.error("Failed to get secondary form status for #{secondary_form.guid}: " \
                             "#{error.message}")
        end

        def should_include_form?(form_id)
          # Check if form is allowed (respects controller restrictions)
          return true if @allowed_forms.nil?

          @allowed_forms.include?(form_id)
        end

        def process_submission(submission, statuses_data, errors)
          response = get_submission_status(submission)
          return if response.nil? # Skip unknown types

          attributes = response.body.dig('data', 'attributes')
          status_record = build_status_record(submission, attributes)
          statuses_data << status_record

          # For SupplementalClaim, check for associated SecondaryAppealForms
          if submission.is_a?(SavedClaim::SupplementalClaim) && should_include_form?('form0995_form4142')
            secondary_statuses = get_secondary_form_statuses(submission)
            statuses_data.concat(secondary_statuses)
          end
        rescue DecisionReviews::V1::ServiceException => e
          handle_decision_reviews_error(e, submission, statuses_data, errors)
        rescue Common::Exceptions::BackendServiceException => e
          errors << error_handler.handle_error(status: 500, body: { error: e.message })
        end

        def build_status_record(submission, attributes)
          normalized_status = normalize_status(attributes['status'])
          {
            'id' => submission.guid,
            'attributes' => {
              'guid' => submission.guid,
              'status' => normalized_status,
              'detail' => attributes['detail'],
              'message' => normalized_status,
              'updated_at' => attributes['updatedAt']
            }
          }
        end

        def handle_decision_reviews_error(error, submission, statuses_data, errors)
          if error.key == 'DR_404'
            status_record = build_not_found_status_record(submission)
            statuses_data << status_record
          else
            error_details = { status: error.original_status || 500,
                              body: error.original_body || { error: error.message } }
            errors << error_handler.handle_error(**error_details)
          end
        end

        def build_not_found_status_record(submission)
          {
            'id' => submission.guid,
            'attributes' => {
              'guid' => submission.guid,
              'status' => 'expired',
              'detail' => 'Submission not found in Decision Reviews system',
              'message' => 'expired',
              'updated_at' => nil
            }
          }
        end

        def get_submission_status(submission)
          case submission.class.name
          when 'SavedClaim::SupplementalClaim'
            decision_review_service.get_supplemental_claim(submission.guid)
          when 'SavedClaim::HigherLevelReview'
            decision_review_service.get_higher_level_review(submission.guid)
          when 'SavedClaim::NoticeOfDisagreement'
            decision_review_service.get_notice_of_disagreement(submission.guid)
          end
        end

        def decision_review_service
          @service ||= DecisionReviews::V1::Service.new
        end

        def benefits_intake_service
          @intake_service ||= BenefitsIntake::Service.new
        end

        def user_appeal_uuids
          AppealSubmission.where(user_account: @user_account)
                          .where(type_of_appeal: %w[SC HLR NOD])
                          .pluck(:submitted_appeal_uuid)
        end

        def base_saved_claim_query(appeal_uuids)
          decision_reviews_classes = [
            'SavedClaim::SupplementalClaim',
            'SavedClaim::HigherLevelReview',
            'SavedClaim::NoticeOfDisagreement'
          ]

          SavedClaim.where(type: decision_reviews_classes)
                    .where(guid: appeal_uuids)
                    .where(delete_date: nil)
        end

        def filter_by_allowed_forms(query)
          form_to_class_map = {
            '20-0995' => 'SavedClaim::SupplementalClaim',
            '20-0996' => 'SavedClaim::HigherLevelReview',
            '10182' => 'SavedClaim::NoticeOfDisagreement'
          }
          allowed_classes = @allowed_forms.map { |form| form_to_class_map[form] }.compact
          return query if allowed_classes.blank?

          query.where(type: allowed_classes)
        end
      end
    end
  end
end
