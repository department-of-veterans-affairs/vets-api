# frozen_string_literal: true

require 'pdf_fill/forms/va214142'
require 'pdf_fill/forms/va210781a'
require 'pdf_fill/forms/va210781'
require 'pdf_fill/forms/va218940'
require 'pdf_fill/forms/va1010cg'
require 'pdf_utilities/datestamp_pdf'
require 'pdf_fill/processors/base_form_4142_processor'
require 'simple_forms_api_submission/metadata_validator'

module EVSS
  module DisabilityCompensationForm
    class Form4142Processor < Processors::BaseForm4142Processor
      def initialize(submission, jid, validate: true)
        @submission = submission
        @jid = jid
        super(validate:) # Pass validate flag to parent
      end

      protected

      def form_data
        @form_data ||= set_signature_date(@submission.form[Form526Submission::FORM_4142])
      end

      def pdf_identifier
        @submission.submitted_claim_id
      end

      def metadata_uuid
        @jid
      end

      def submission_date
        @submission.created_at.in_time_zone(TIMEZONE)
      end

      # Flip this on to use the 2024 template, teams can make independent decisions about when to use the 2024 version
      def generate_2024_version?
        Flipper.enabled?(:evss_form4142_use_2024_template)
      end
    end
  end
end
