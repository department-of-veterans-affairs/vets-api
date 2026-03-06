# frozen_string_literal: true

require 'forms/submission_statuses/pdf_urls'
require_relative 'base_formatter'

module Forms
  module SubmissionStatuses
    module Formatters
      class BenefitsIntakeFormatter < BaseFormatter
        private

        def merge_record(submission_map, status)
          submission = submission_map[status['attributes']['guid']]
          if submission
            submission.detail = status['attributes']['detail']
            submission.message = status['attributes']['message']
            submission.status = status['attributes']['status']
            submission.updated_at = status['attributes']['updated_at']
          end
        end

        def build_submissions_map(submissions)
          submissions.each_with_object({}) do |submission, hash|
            pdf_urls = PdfUrls.new(
              form_id: submission.form_type,
              submission_guid: submission.benefits_intake_uuid
            )
            supported = pdf_urls.supported?
            hash[submission.benefits_intake_uuid] = OpenStruct.new(
              id: submission.benefits_intake_uuid,
              detail: nil,
              form_type: submission.form_type,
              message: nil,
              status: nil,
              created_at: submission.created_at,
              updated_at: nil,
              pdf_support: supported,
              presigned_url: supported ? fetch_presigned_url(pdf_urls, submission.benefits_intake_uuid) : nil
            )
          end
        end

        def fetch_presigned_url(pdf_urls, submission_guid)
          pdf_urls.fetch_url
        rescue => e
          Rails.logger.warn(
            'Failed to fetch presigned URL for submission in Forms::SubmissionStatuses',
            submission_guid:,
            error: e.message
          )
          nil
        end
      end
    end
  end
end
