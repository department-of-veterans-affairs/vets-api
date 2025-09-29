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
          # Query SavedClaim records for Decision Reviews forms via AppealSubmission
          # AppealSubmission has the user_account relationship, SavedClaim may not
          appeal_submissions = AppealSubmission.where(user_account: @user_account)
                                               .where(type_of_appeal: %w[SC HLR NOD])

          # Get the submitted_appeal_uuids to find associated SavedClaims
          appeal_uuids = appeal_submissions.pluck(:submitted_appeal_uuid)

          decision_reviews_classes = [
            'SavedClaim::SupplementalClaim',
            'SavedClaim::HigherLevelReview',
            'SavedClaim::NoticeOfDisagreement'
          ]

          query = SavedClaim.where(type: decision_reviews_classes)
                            .where(guid: appeal_uuids)
                            .where(delete_date: nil)

          if @allowed_forms.present?
            # Map form numbers to class names for filtering
            form_to_class_map = {
              '20-0995' => 'SavedClaim::SupplementalClaim',
              '20-0996' => 'SavedClaim::HigherLevelReview',
              '10182' => 'SavedClaim::NoticeOfDisagreement'
            }
            allowed_classes = @allowed_forms.map { |form| form_to_class_map[form] }.compact
            query = query.where(type: allowed_classes) if allowed_classes.present?
          end

          query.order(created_at: :asc).to_a
        end

        def api_statuses(submissions)
          # Fetch statuses from Decision Reviews V1 Service
          # Similar to SavedClaimStatusUpdaterJob#get_status_and_attributes
          statuses_data = []
          errors = []

          submissions.each do |submission|
            begin
              # Get primary submission status
              response = get_submission_status(submission)
              next if response.nil? # Skip unknown types

              attributes = response.body.dig('data', 'attributes')

              # Transform to match expected format
              status_record = {
                'id' => submission.guid,
                'attributes' => {
                  'guid' => submission.guid,
                  'status' => attributes['status'],
                  'detail' => attributes['detail'],
                  'message' => attributes['status'], # Use status as message for consistency
                  'updated_at' => attributes['updatedAt']
                }
              }
              statuses_data << status_record

              # For SupplementalClaim, check for associated SecondaryAppealForms (21-4142)
              if submission.is_a?(SavedClaim::SupplementalClaim) && should_include_form?('21-4142')
                secondary_statuses = get_secondary_form_statuses(submission)
                statuses_data.concat(secondary_statuses)
              end

            rescue DecisionReviews::V1::ServiceException => e
              if e.key == 'DR_404'
                # Handle not found cases
                status_record = {
                  'id' => submission.guid,
                  'attributes' => {
                    'guid' => submission.guid,
                    'status' => 'DR_404',
                    'detail' => 'Not found',
                    'message' => 'Not found',
                    'updated_at' => nil
                  }
                }
                statuses_data << status_record
              else
                errors << error_handler.handle_error(status: e.original_status || 500, body: e.original_body || { error: e.message })
              end
            rescue => e
              errors << error_handler.handle_error(status: 500, body: { error: e.message })
            end
          end

          [statuses_data, errors.any? ? errors : nil]
        end

        private

        def get_secondary_form_statuses(submission)
          secondary_statuses = []

          # Check if this SupplementalClaim has associated SecondaryAppealForms
          return secondary_statuses unless submission.appeal_submission&.secondary_appeal_forms&.any?

          submission.appeal_submission.secondary_appeal_forms.each do |secondary_form|
            response = benefits_intake_service.get_status(uuid: secondary_form.guid)

            attributes = response.body.dig('data', 'attributes')

            status_record = {
              'id' => secondary_form.guid,
              'attributes' => {
                'guid' => secondary_form.guid,
                'status' => attributes['status'],
                'detail' => attributes['detail'],
                'message' => attributes['status'],
                'created_at' => secondary_form.created_at,
                'updated_at' => attributes['updated_at'],
                'form_type' => secondary_form.form_id
              }
            }
            secondary_statuses << status_record
          rescue => e
            # Handle errors but don't fail entire request
            Rails.logger.error("Failed to get secondary form status for #{secondary_form.guid}: #{e.message}")
          end

          secondary_statuses
        end

        def should_include_form?(form_id)
          # Check if form is allowed (respects controller restrictions)
          return true if @allowed_forms.nil?

          @allowed_forms.include?(form_id)
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
      end
    end
  end
end
