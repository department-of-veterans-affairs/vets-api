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
            hash[submission.benefits_intake_uuid] = OpenStruct.new(
              id: submission.benefits_intake_uuid,
              detail: nil,
              form_type: submission.form_type,
              message: nil,
              status: nil,
              created_at: submission.created_at,
              updated_at: nil,
              pdf_support: pdf_supported?(submission)
            )
          end
        end

        def pdf_supported?(submission)
          PdfUrls.new(
            form_id: submission.form_type,
            submission_guid: submission.benefits_intake_uuid
          ).supported?
        end
      end
    end
  end
end
