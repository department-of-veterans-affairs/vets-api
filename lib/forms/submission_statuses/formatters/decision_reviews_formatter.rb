# frozen_string_literal: true

require_relative '../pdf_urls'
require_relative 'base_formatter'

module Forms
  module SubmissionStatuses
    module Formatters
      class DecisionReviewsFormatter < BaseFormatter
        private

        def merge_record(submission_map, status)
          guid = status['attributes']['guid']
          submission = submission_map[guid]

          # If submission not found, it might be a SecondaryAppealForm - create entry
          unless submission
            if status['attributes']['form_type'] # Check if it's a secondary form
              submission = create_secondary_form_entry(status)
              submission_map[guid] = submission
            else
              return # Skip if we can't identify the submission
            end
          end

          # Merge status data
          submission.detail = status['attributes']['detail']
          submission.message = status['attributes']['message']
          submission.status = status['attributes']['status']
          submission.updated_at = parse_date(status['attributes']['updated_at'])
        end

        def build_submissions_map(submissions)
          submissions.each_with_object({}) do |submission, hash|
            hash[submission.guid] = OpenStruct.new(
              id: submission.guid,
              detail: nil,
              form_type: determine_form_type(submission),
              message: nil,
              status: nil,
              created_at: submission.created_at,
              updated_at: nil,
              pdf_support: false # API doesn't support pdf download urls yet
            )
          end
        end

        def create_secondary_form_entry(status)
          # Create a submission entry for SecondaryAppealForm records
          form_type = status['attributes']['form_type']
          guid = status['attributes']['guid']

          OpenStruct.new(
            id: guid,
            detail: status['attributes']['detail'],
            form_type:,
            message: status['attributes']['message'],
            status: status['attributes']['status'],
            created_at: status['attributes']['created_at'],
            updated_at: status['attributes']['updated_at'],
            pdf_support: false # API doesn't support pdf download urls yet
          )
        end

        def determine_form_type(submission)
          # Map SavedClaim class names and SecondaryAppealForm to form types
          case submission.class.name
          when 'SavedClaim::SupplementalClaim'
            '20-0995' # Supplemental Claim form
          when 'SavedClaim::HigherLevelReview'
            '20-0996' # Higher Level Review form
          when 'SavedClaim::NoticeOfDisagreement'
            '10182' # Notice of Disagreement form
          when 'SecondaryAppealForm'
            'form0995_form4142' # to support friendlier labeling in vets-website
          else
            'unknown'
          end
        end

        def parse_date(date_string)
          return nil if date_string.nil?

          begin
            Time.zone.parse(date_string)
          rescue ArgumentError
            nil
          end
        end
      end
    end
  end
end
