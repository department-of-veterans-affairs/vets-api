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
      def initialize(submission, jid)
        @submission = submission
        @jid = jid
        super()
      end

      protected

      def transform_provider_facilities(incoming_data)
        provider_facilities = incoming_data.dig('form4142', 'providerFacility')
        return incoming_data if provider_facilities.blank?

        provider_facilities.map! do |facility|
          treated_disability_hash = facility['treatedDisabilityNames']
          if treated_disability_hash.blank?
            facility.merge!('conditionsTreated' => '')
          else
            facility.merge!('conditionsTreated' => treated_disability_hash.select do |_, checked|
              checked
            end.keys.join(', '))
          end
        end
        incoming_data
      end

      def transform_form_data(incoming_data)
        if generate_2024_version?
          # Transform the incoming data to match the expected new 2024 structure
          # For now, only provider facilities are transformed, but could need more in the future
          transform_provider_facilities(incoming_data)
        else
          incoming_data
        end
      end

      def form_data
        @form_data ||= transform_form_data(set_signature_date(@submission.form[Form526Submission::FORM_4142]))
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

      # Flip this on to use the 2024 PDF template
      def generate_2024_version?
        Flipper.enabled?(:disability_526_form4142_use_2024_template)
      end

      # Flip this on to validate the schema of the form data
      def should_validate_schema?
        Flipper.enabled?(:disability_526_form4142_validate_schema)
      end
    end
  end
end
