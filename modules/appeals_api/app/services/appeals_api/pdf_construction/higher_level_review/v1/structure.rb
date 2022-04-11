# frozen_string_literal: true

require 'prawn/table'

module AppealsApi
  module PdfConstruction
    module HigherLevelReview::V1
      class Structure
        MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM = 6

        def initialize(higher_level_review)
          @higher_level_review = higher_level_review
        end

        # rubocop:disable Metrics/MethodLength
        def form_fill
          options = {
            form_fields.first_name => form_data.first_name,
            form_fields.middle_initial => form_data.middle_initial,
            form_fields.last_name => form_data.last_name,
            form_fields.first_three_ssn => form_data.first_three_ssn,
            form_fields.second_two_ssn => form_data.second_two_ssn,
            form_fields.last_four_ssn => form_data.last_four_ssn,
            form_fields.birth_month => form_data.birth_month,
            form_fields.birth_day => form_data.birth_day,
            form_fields.birth_year => form_data.birth_year,
            form_fields.file_number => form_data.file_number,
            form_fields.service_number => form_data.service_number,
            form_fields.insurance_policy_number => form_data.insurance_policy_number,
            form_fields.claimant_type(0) => form_data.claimant_type(0),
            form_fields.claimant_type(1) => form_data.claimant_type(1),
            form_fields.claimant_type(2) => form_data.claimant_type(2),
            form_fields.claimant_type(3) => form_data.claimant_type(3),
            form_fields.claimant_type(4) => form_data.claimant_type(4),
            form_fields.mailing_address_street => form_data.mailing_address_street,
            form_fields.mailing_address_unit_number => form_data.mailing_address_unit_number,
            form_fields.mailing_address_city => form_data.mailing_address_city,
            form_fields.mailing_address_state => form_data.mailing_address_state,
            form_fields.mailing_address_country => form_data.mailing_address_country,
            form_fields.mailing_address_zip_first_5 => form_data.mailing_address_zip_first_5,
            form_fields.mailing_address_zip_last_4 => form_data.mailing_address_zip_last_4,
            form_fields.veteran_phone_number => form_data.veteran_phone_number,
            form_fields.veteran_email => form_data.veteran_email,
            form_fields.benefit_type(0) => form_data.benefit_type('nca'),
            form_fields.benefit_type(1) => form_data.benefit_type('vha'),
            form_fields.benefit_type(2) => form_data.benefit_type('education'),
            form_fields.benefit_type(3) => form_data.benefit_type('insurance'),
            form_fields.benefit_type(4) => form_data.benefit_type('loan_guaranty'),
            form_fields.benefit_type(5) => form_data.benefit_type('fiduciary'),
            form_fields.benefit_type(6) => form_data.benefit_type('voc_rehab'),
            form_fields.benefit_type(7) => form_data.benefit_type('pension_survivors_benefits'),
            form_fields.benefit_type(8) => form_data.benefit_type('compensation'),
            form_fields.same_office => form_data.same_office,
            form_fields.informal_conference => form_data.informal_conference,
            form_fields.conference_8_to_10 => form_data.informal_conference_times('800-1000 ET'),
            form_fields.conference_10_to_1230 => form_data.informal_conference_times('1000-1230 ET'),
            form_fields.conference_1230_to_2 => form_data.informal_conference_times('1230-1400 ET'),
            form_fields.conference_2_to_430 => form_data.informal_conference_times('1400-1630 ET'),
            form_fields.rep_name_and_phone_number => form_data.rep_name_and_phone_number,
            form_fields.signature => form_data.signature,
            form_fields.date_signed => form_data.date_signed
          }

          fill_contestable_issues!(options)
        end
        # rubocop:enable Metrics/MethodLength

        def insert_overlaid_pages(form_fill_path)
          form_fill_path
        end

        def add_additional_pages
          return unless additional_pages?

          @additional_pages_pdf ||= Prawn::Document.new(skip_page_creation: true)

          HigherLevelReview::Pages::V1::AdditionalIssues.new(
            @additional_pages_pdf,
            form_data
          ).build!

          @additional_pages_pdf
        end

        def final_page_adjustments
          # no-op
        end

        def form_title
          '200996'
        end

        def stamp(unstamped_path)
          stamped_pdf_path = CentralMail::DatestampPdf.new(unstamped_path).run(
            text: "Submitted by #{higher_level_review.consumer_name} via api.va.gov",
            x: 429,
            y: 782,
            text_only: true
          )

          CentralMail::DatestampPdf.new(stamped_pdf_path).run(
            text: "API.VA.GOV #{higher_level_review.created_at.utc.strftime('%Y-%m-%d %H:%M%Z')}",
            x: 5,
            y: 5,
            text_only: true
          )
        end

        private

        attr_accessor :higher_level_review

        def form_fields
          @form_fields ||= HigherLevelReview::V1::FormFields.new
        end

        def form_data
          @form_data ||= HigherLevelReview::V1::FormData.new(higher_level_review)
        end

        def additional_pages?
          form_data.contestable_issues.count > MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM
        end

        def fill_contestable_issues!(options)
          form_issues = form_data.contestable_issues.take(MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM)
          form_issues.each_with_index do |issue, index|
            options[form_fields.contestable_issue_fields_array[index]] = issue.text
            options[form_fields.issue_decision_date_fields_array[index]] = issue.decision_date
          end

          options
        end
      end
    end
  end
end
