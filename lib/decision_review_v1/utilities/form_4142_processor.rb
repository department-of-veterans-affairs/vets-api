# frozen_string_literal: true

require 'pdf_fill/processors/base_form_4142_processor'
require 'decision_review_v1/utilities/constants'

module DecisionReviewV1
  module Processor
    class Form4142Processor < Processors::BaseForm4142Processor
      def initialize(form_data:, submission_id: nil)
        @submission = Form526Submission.find_by(id: submission_id)
        @form = set_signature_date(form_data)
        super()
      end

      protected

      def form_data
        @form
      end

      def pdf_identifier
        uuid
      end

      def metadata_uuid
        uuid
      end

      def submission_date
        if @submission.nil?
          Time.now.in_time_zone(TIMEZONE)
        else
          @submission.created_at.in_time_zone(TIMEZONE)
        end
      end

      # Flip this on to use the 2024 PDF template
      def generate_2024_version?
        true
      end

      # Flip this on to validate the schema of the form data
      def should_validate_schema?
        Flipper.enabled?(:decision_review_form4142_validate_schema)
      end

      private

      def uuid
        @uuid ||= SecureRandom.uuid
      end
    end
  end
end
