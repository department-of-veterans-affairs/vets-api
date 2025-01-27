# frozen_string_literal: true

require_relative 'pdf_urls'

module Forms
  module SubmissionStatuses
    class Formatter
      def format_data(dataset)
        return [] unless dataset.submissions?

        results = merge_records_from(dataset)
        dataset.intake_statuses? ? sort_results(results) : results
      end

      private

      def sort_results(results)
        results&.sort_by { |record| [record.updated_at ? 1 : 0, record.updated_at] }
      end

      def merge_records_from(dataset)
        merge_records(dataset.submissions, dataset.intake_statuses)
      end

      def merge_records(submissions, statuses)
        submission_map = build_submissions_map(submissions)
        statuses&.each { |status| merge_record(submission_map, status) }

        submission_map.values
      end

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
