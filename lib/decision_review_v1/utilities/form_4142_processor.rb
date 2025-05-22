# frozen_string_literal: true

require 'processors/base_form_4142_processor'
require 'decision_review_v1/utilities/constants'

module DecisionReviewV1
  module Processor
    class Form4142Processor < Processors::BaseForm4142Processor
      FORM_ID = '21-4142'

      def initialize(form_data:, submission_id: nil, validate: true)
        @submission = Form526Submission.find_by(id: submission_id)
        @form = set_signature_date(form_data)
        super(validate: validate) # Pass validate flag to parent
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

      def country_code_for_us_validation
        'US'
      end

      def form_id
        FORM_ID
      end
    end
  end
end
