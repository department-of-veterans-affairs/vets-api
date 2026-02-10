# frozen_string_literal: true

require_relative 'base_formatter'

module Forms
  module SubmissionStatuses
    module Formatters
      class IvcChampvaFormatter < BaseFormatter
        private

        def merge_record(submission_map, status)
          submission = submission_map[status['attributes']['guid']]
          return unless submission

          submission.detail = status['attributes']['detail']
          submission.message = status['attributes']['message']
          submission.status = status['attributes']['status']
          submission.updated_at = status['attributes']['updated_at']
        end

        def build_submissions_map(submissions)
          submissions.each_with_object({}) do |submission, hash|
            hash[submission.id] = OpenStruct.new(
              id: submission.id,
              detail: nil,
              form_type: submission.form_type,
              message: nil,
              status: nil,
              created_at: submission.created_at,
              updated_at: submission.updated_at,
              pdf_support: false
            )
          end
        end
      end
    end
  end
end
