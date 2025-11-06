# frozen_string_literal: true

module Forms
  module SubmissionStatuses
    module Formatters
      # Base class for implementing custom formatters for different Form APIs
      #
      # Example usage for a new Form API:
      #
      # class MyNewFormatter < BaseFormatter
      #   private
      #
      #   def build_submissions_map(submissions)
      #     # Build a hash mapping submission IDs to OpenStruct objects
      #     # Must include: id, form_type, created_at, updated_at, detail, message, status, pdf_support
      #   end
      #
      #   def merge_record(submission_map, status)
      #     # Update submission with status data from your API
      #     # Handle your API's specific response format
      #   end
      #
      #   def pdf_supported?(submission)
      #     # Determine if PDF generation is supported for this form
      #   end
      # end
      class BaseFormatter
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

        # Override this method in your formatter implementation
        def merge_record(submission_map, status)
          raise NotImplementedError, 'Subclasses must implement #merge_record method'
        end

        # Override this method in your formatter implementation
        def build_submissions_map(submissions)
          raise NotImplementedError, 'Subclasses must implement #build_submissions_map method'
        end

        # Override this method in your formatter implementation if needed
        def pdf_supported?(_submission)
          false
        end
      end
    end
  end
end
