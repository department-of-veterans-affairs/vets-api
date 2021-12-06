# frozen_string_literal: true

require 'prawn/table'

module AppealsApi
  module PdfConstruction
    module HigherLevelReview::V2
      class Structure
        NUMBER_OF_ISSUES_FIRST_PAGE = 7
        NUMBER_OF_ISSUES_SECOND_PAGE = 6
        MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM = (NUMBER_OF_ISSUES_FIRST_PAGE + NUMBER_OF_ISSUES_SECOND_PAGE).freeze
        SHORT_EMAIL_LENGTH = 100

        def initialize(higher_level_review)
          @higher_level_review = higher_level_review
        end

        # rubocop:disable Metrics/MethodLength
        def form_fill
          options = {
            # Section I: Vet's ID
            # Veteran name is filled out through autosize text box, not pdf fields
            form_fields.middle_initial => form_data.middle_initial,
            form_fields.first_three_ssn => form_data.first_three_ssn,
            form_fields.second_two_ssn => form_data.second_two_ssn,
            form_fields.last_four_ssn => form_data.last_four_ssn,
            form_fields.file_number => form_data.file_number,
            form_fields.birth_month => form_data.birth_mm,
            form_fields.birth_day => form_data.birth_dd,
            form_fields.birth_year => form_data.birth_yyyy,
            form_fields.insurance_policy_number => form_data.insurance_policy_number,
            form_fields.mailing_address_state => form_data.state_code,
            form_fields.mailing_address_country => form_data.country_code,
            form_fields.veteran_homeless => form_data.veteran_homeless,
            form_fields.veteran_phone_area_code => form_data.veteran_phone_area_code,
            form_fields.veteran_phone_prefix => form_data.veteran_phone_prefix,
            form_fields.veteran_phone_line_number => form_data.veteran_phone_line_number,
            form_fields.veteran_phone_international_number => form_data.veteran_phone_international_number,

            # Section II: Claimant's ID
            # NOT YET SUPPORTED

            # Section III: Benefit Type
            form_fields.benefit_type(0) => form_data.benefit_type('education'),
            form_fields.benefit_type(1) => form_data.benefit_type('nationalCemeteryAdministration'),
            form_fields.benefit_type(2) => form_data.benefit_type('veteransHealthAdministration'),
            form_fields.benefit_type(3) => form_data.benefit_type('lifeInsurance'),
            form_fields.benefit_type(4) => form_data.benefit_type('loanGuaranty'),
            form_fields.benefit_type(5) => form_data.benefit_type('fiduciary'),
            form_fields.benefit_type(6) => form_data.benefit_type('readinessAndEmployment'),
            form_fields.benefit_type(7) => form_data.benefit_type('pensionSurvivorsBenefits'),
            form_fields.benefit_type(8) => form_data.benefit_type('compensation'),

            # Section IV: Optional Informal Conference
            form_fields.informal_conference => form_data.informal_conference,
            form_fields.conference_8_to_12 => form_data.informal_conference_time('veteran', '800-1200 ET'),
            form_fields.conference_12_to_1630 => form_data.informal_conference_time('veteran', '1200-1630 ET'),
            form_fields.conference_rep_8_to_12 => form_data.informal_conference_time('representative', '800-1200 ET'),
            form_fields.conference_rep_12_to_1630 => form_data.informal_conference_time('representative',
                                                                                        '1200-1630 ET'),
            # Rep name should be filled with autosize text boxes, not pdf fields
            form_fields.rep_phone_area_code => form_data.rep_phone_area_code,
            form_fields.rep_phone_prefix => form_data.rep_phone_prefix,
            form_fields.rep_phone_line_number => form_data.rep_phone_line_number,

            # Section V: SOC/SSOC Opt-In
            form_fields.sso_ssoc_opt_in => form_data.soc_opt_in,

            # Section VI: Issues (allows 13 in fields)
            # Dates filled via fill_contestable_issues_dates!, below.
            # Issue text is filled out through autosize text boxes.

            # Section VII: Cert & Sig
            form_fields.date_signed_month => form_data.date_signed_mm,
            form_fields.date_signed_day => form_data.date_signed_dd,
            form_fields.date_signed_year => form_data.date_signed_yyyy

            # Section VIII: Authorized Rep Sig
            # NOT YET SUPPORTED
          }

          fill_contestable_issues_dates!(options)
        end
        # rubocop:enable Metrics/MethodLength

        def insert_overlaid_pages(form_fill_path)
          pdftk = PdfForms.new(Settings.binaries.pdftk)

          output_path = "/tmp/HLRv2-#{higher_level_review.id}-overlaid-form-fill-tmp.pdf"

          temp_path = fill_autosize_fields
          pdftk.multistamp(form_fill_path, temp_path, output_path)
          output_path
        end

        def add_additional_pages
          return unless additional_pages?

          @additional_pages_pdf ||= Prawn::Document.new(skip_page_creation: true)

          HigherLevelReview::Pages::V2::AdditionalIssues.new(
            @additional_pages_pdf,
            form_data
          ).build!

          @additional_pages_pdf
        end

        def final_page_adjustments
          # no-op
        end

        def form_title
          '200996_v2'
        end

        def stamp(stamped_pdf_path)
          stamper = CentralMail::DatestampPdf.new(stamped_pdf_path)

          bottom_stamped_path = stamper.run(
            text: "API.VA.GOV #{higher_level_review.created_at.utc.strftime('%Y-%m-%d %H:%M%Z')}",
            x: 5,
            y: 775,
            text_only: true
          )

          name_stamp_path = "#{Common::FileHelpers.random_file_path}.pdf"
          Prawn::Document.generate(name_stamp_path, margin: [0, 0]) do |pdf|
            pdf.text_box form_data.stamp_text,
                         at: [205, 785],
                         align: :center,
                         valign: :center,
                         overflow: :shrink_to_fit,
                         min_font_size: 8,
                         width: 215,
                         height: 10
          end

          CentralMail::DatestampPdf.new(nil).stamp(bottom_stamped_path, name_stamp_path)
        end

        private

        def fill_autosize_fields
          tmp_path = "/#{::Common::FileHelpers.random_file_path}.pdf"
          Prawn::Document.generate(tmp_path) do |pdf|
            pdf.font 'Courier'

            whiteout_line pdf, :first_name
            whiteout_line pdf, :last_name
            whiteout_line pdf, :number_and_street
            whiteout_line pdf, :city
            whiteout_line pdf, :zip_code
            whiteout_line pdf, :veteran_email, text_override: 'See attached page for veteran email'
            pdf.start_new_page

            whiteout_line pdf, :rep_first_name
            whiteout_line pdf, :rep_last_name
            whiteout_line pdf, :rep_email, text_override: 'See attached page for representative email'
            whiteout_line pdf, :rep_international_number
            whiteout_line pdf, :rep_domestic_ext
            fill_contestable_issues_text pdf
            pdf.text_box form_data.signature,
                         default_text_opts.merge(form_fields.boxes[:signature])
          end
          tmp_path
        end

        attr_accessor :higher_level_review

        def default_text_opts
          { overflow: :shrink_to_fit,
            min_font_size: 8,
            valign: :bottom }.freeze
        end

        def form_fields
          @form_fields ||= HigherLevelReview::V2::FormFields.new
        end

        def form_data
          @form_data ||= HigherLevelReview::V2::FormData.new(higher_level_review)
        end

        def additional_pages?
          form_data.contestable_issues.count > MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM || any_long_emails?
        end

        def any_long_emails?
          form_data.veteran_email.length > SHORT_EMAIL_LENGTH || form_data.rep_email.length > SHORT_EMAIL_LENGTH
        end

        def fill_contestable_issues_dates!(options)
          form_issues = form_data.contestable_issues.take(MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM)
          form_issues.each_with_index do |issue, index|
            date_fields = form_fields.issue_decision_date_fields(index)
            date = issue.decision_date
            options[date_fields[:month]] = date.strftime '%m'
            options[date_fields[:day]] = date.strftime '%d'
            options[date_fields[:year]] = date.strftime '%Y'
          end
          options
        end

        def fill_contestable_issues_text(pdf)
          issues = form_data.contestable_issues.take(MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM)

          fill_issues_first_page(issues, pdf)
          pdf.start_new_page # Always start a new page even if there are no issues so other text can insert properly
          fill_issues_second_page(issues, pdf)
        end

        def fill_issues_first_page(issues, pdf)
          issues.first(NUMBER_OF_ISSUES_FIRST_PAGE).each_with_index do |issue, i|
            if issue.text_exists?
              pdf.text_box issue.text, default_text_opts.merge(form_fields.boxes[:issues_pg1][i])
              pdf.text_box form_data.soc_date_text(issue), default_text_opts.merge(form_fields.boxes[:soc_date_pg1][i])
            end

            if issue.disagreement_area
              pdf.text_box "Area of Disagreement: #{issue.disagreement_area}",
                           default_text_opts.merge(form_fields.boxes[:disagreement_area_pg1][i])
            end
          end
        end

        def fill_issues_second_page(issues, pdf)
          issues.drop(NUMBER_OF_ISSUES_FIRST_PAGE).each_with_index do |issue, i|
            if issue.text_exists?
              pdf.text_box issue.text, default_text_opts.merge(form_fields.boxes[:issues_pg2][i])
              pdf.text_box form_data.soc_date_text(issue), default_text_opts.merge(form_fields.boxes[:soc_date_pg2][i])
            end

            if issue.disagreement_area
              pdf.text_box "Area of Disagreement: #{issue.disagreement_area}",
                           default_text_opts.merge(form_fields.boxes[:disagreement_area_pg2][i])
            end
          end
        end

        def whiteout(pdf, at:, width:, height: 15)
          pdf.fill_color 'ffffff'
          pdf.fill_rectangle at, width, height
          pdf.fill_color '000000'
        end

        def whiteout_line(pdf, attr, text_override: nil, length_for_override: SHORT_EMAIL_LENGTH)
          text_opts = form_fields.boxes[attr].merge(default_text_opts).merge(
            height: 13
          )
          whiteout pdf, form_fields.boxes[attr]

          text = form_data.send(attr)
          text = text_override if text_override.present? && text.length > length_for_override
          pdf.text_box text, text_opts
        end
      end
    end
  end
end
