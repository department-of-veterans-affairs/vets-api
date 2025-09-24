# frozen_string_literal: true

# Example implementation for teams adding new Form APIs

# This is a template showing how to implement a formatter for a new Form API.
# Replace "Example" with your actual service name and implement the required methods.

require_relative 'base_formatter'

module Forms
  module SubmissionStatuses
    module Formatters
      class ExampleFormatter < BaseFormatter
        private

        def merge_record(submission_map, status)
          # TODO: Implement status merging for your API response format
          # Example for a different API format:
          # submission = submission_map[status['id']] # or status['submission_guid'], etc.
          # if submission
          #   submission.detail = status['details']
          #   submission.message = status['status_message']
          #   submission.status = status['current_status']
          #   submission.updated_at = status['last_updated']
          # end

          raise NotImplementedError, 'Implement status merging for your API response format'
        end

        def build_submissions_map(submissions)
          # TODO: Implement submission mapping for your form structure
          # The key should match the ID field used in your API responses
          # Example:
          # submissions.each_with_object({}) do |submission, hash|
          #   hash[submission.your_unique_id] = OpenStruct.new(
          #     id: submission.your_unique_id,
          #     detail: nil,
          #     form_type: submission.form_type,
          #     message: nil,
          #     status: nil,
          #     created_at: submission.created_at,
          #     updated_at: nil,
          #     pdf_support: pdf_supported?(submission)
          #   )
          # end
          
          raise NotImplementedError, 'Implement submission mapping for your form structure'
        end

        def pdf_supported?(_submission)
          # TODO: Implement PDF support check for your forms
          # Example:
          # YourPdfService.new(form_id: submission.form_type).supported?
          # or simply return true/false based on your requirements
          
          false # Default to no PDF support
        end
      end
    end
  end
end
