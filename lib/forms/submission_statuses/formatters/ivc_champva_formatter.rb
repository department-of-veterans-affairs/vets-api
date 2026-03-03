# frozen_string_literal: true

require_relative 'base_formatter'

module Forms
  module SubmissionStatuses
    module Formatters
      class IvcChampvaFormatter < BaseFormatter
        FORM_TYPE_MAP = {
          '10-10d-extended' => '10-10D'
        }.freeze

        STATUS_MAP = {
          # PEGA statuses
          'submitted' => 'pending',
          'processed' => 'vbms',
          'not processed' => 'error',
          'manually processed' => 'vbms',

          # VES statuses
          'ok' => 'pending',
          'internal_server_error' => 'error',

          # Shared statuses seen across sources
          'vbms' => 'vbms',
          'complete' => 'vbms',
          'completed' => 'vbms',
          'closed' => 'vbms',
          'error' => 'error',
          'failed' => 'error',
          'rejected' => 'error',
          'submission failed' => 'error',
          'action needed' => 'error',
          'expired' => 'error'
        }.freeze

        private

        # IVC CHAMPVA data is already denormalized in the DB row, so no external
        # status payload merging is needed.
        def merge_record(_submission_map, _status)
          nil
        end

        def build_submissions_map(submissions)
          submissions.each_with_object({}) do |submission, hash|
            form_type = normalize_form_type(submission.form_number)
            hash[submission.form_uuid.to_s] = OpenStruct.new(
              id: submission.form_uuid.to_s,
              detail: submission.case_id,
              form_type:,
              message: nil,
              status: normalize_status(submission),
              created_at: submission.created_at,
              updated_at: submission.updated_at,
              pdf_support: false,
              card_metadata: card_metadata_for(form_type)
            )
          end
        end

        def normalize_status(submission)
          [submission.pega_status, submission.ves_status, submission.s3_status].each do |raw_status|
            next if raw_status.blank?

            mapped_status = STATUS_MAP[raw_status.to_s.downcase.strip]
            return mapped_status if mapped_status.present?
          end

          'pending'
        end

        def normalize_form_type(form_number)
          normalized = form_number.to_s.downcase.strip
          FORM_TYPE_MAP.fetch(normalized, form_number.to_s.upcase)
        end
      end
    end
  end
end
