# frozen_string_literal: true

require 'common/file_helpers'

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V2
        class Structure
          MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM = 7
          MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM = 3
          SHORT_EMAIL_LENGTH = 50

          def initialize(supplemental_claim)
            @supplemental_claim = supplemental_claim
          end

          # rubocop:disable Metrics/MethodLength
          def form_fill
            # Section I: Identifying Information
            # Name, address and email filled out through autosize text box, not pdf fields
            {
              # Vet's ID
              # Veteran name is filled out through autosize text box, not pdf fields
              form_fields.veteran_middle_initial => form_data.veteran.middle_initial,
              form_fields.veteran_ssn_first_three => form_data.veteran_ssn_first_three,
              form_fields.veteran_ssn_middle_two => form_data.veteran_ssn_middle_two,
              form_fields.veteran_ssn_last_four => form_data.veteran_ssn_last_four,
              form_fields.file_number => form_data.veteran.file_number,
              form_fields.veteran_service_number => form_data.veteran.service_number,
              form_fields.veteran_dob_month => form_data.veteran_dob_month,
              form_fields.veteran_dob_day => form_data.veteran_dob_day,
              form_fields.veteran_dob_year => form_data.veteran_dob_year,
              form_fields.insurance_policy_number => form_data.veteran.insurance_policy_number,
              form_fields.mailing_address_state => form_data.signing_appellant.state_code,
              form_fields.mailing_address_country => form_data.signing_appellant.country_code,

              # Claimant
              # Claimant name is filled out through autosize text box, not pdf fields
              form_fields.claimant_middle_initial => form_data.claimant.middle_initial,
              form_fields.claimant_type => form_data.claimant_type,
              form_fields.benefit_type => form_data.benefit_type,

              # Section II: Issues (allows 7 in document fields)
              # Issues and dates filled out via text box
              form_fields.soc_ssoc_opt_in => form_data.soc_ssoc_opt_in,

              # Section III: New and Relevant Evidence
              # Name and Location, and Date text filled out through autosize text boxes

              # Section IV: 5103 Notice Acknowledgement
              form_fields.form_5103_notice_acknowledged => form_data.form_5103_notice_acknowledged,

              # Section V: Signatures
              form_fields.date_signed => (form_data.date_signed if form_data.alternate_signer_full_name.blank?),
              form_fields.alternate_signer_date_signed =>
                (form_data.date_signed if form_data.alternate_signer_full_name.present?)
            }
          end
          # rubocop:enable Metrics/MethodLength

          def insert_overlaid_pages(form_fill_path)
            pdftk = PdfForms.new(Settings.binaries.pdftk)

            output_path = "/tmp/#{supplemental_claim.id}-overlaid-form-fill-tmp.pdf"

            temp_path = fill_autosize_fields
            pdftk.multistamp(form_fill_path, temp_path, output_path)
            output_path
          end

          def add_additional_pages
            return unless additional_pages?

            @additional_pages_pdf ||= Prawn::Document.new(skip_page_creation: true)

            Pages::AdditionalPages.new(
              @additional_pages_pdf,
              form_data
            ).build!

            @additional_pages_pdf
          end

          def final_page_adjustments
            # Removes first 2 boilerplate pages
            ['3-end']
          end

          def form_title
            '200995'
          end

          private

          attr_accessor :supplemental_claim

          def default_text_opts
            { overflow: :shrink_to_fit,
              min_font_size: 8,
              valign: :bottom }.freeze
          end

          def form_fields
            @form_fields ||= FormFields.new
          end

          def form_data
            @form_data ||= FormData.new(supplemental_claim)
          end

          # rubocop:disable Metrics/MethodLength
          def fill_autosize_fields
            tmp_path = "/#{::Common::FileHelpers.random_file_path}.pdf"
            Prawn::Document.generate(tmp_path) do |pdf|
              2.times { pdf.start_new_page }

              pdf.font 'Courier'

              fill_text pdf, :veteran_first_name
              fill_text pdf, :veteran_last_name
              fill_text pdf, :signing_appellant_number_and_street
              fill_text pdf, :signing_appellant_city
              fill_text pdf, :signing_appellant_zip_code
              fill_text pdf, :signing_appellant_phone
              fill_text pdf, :signing_appellant_email,
                        long_text_override: 'See attached page for appellant email'

              fill_text pdf, :claimant_first_name
              fill_text pdf, :claimant_last_name

              fill_text pdf, :claimant_type_other_text

              fill_contestable_issues_text pdf
              pdf.start_new_page

              # if alternate signer provided, leave vet_claimant\rep signature blank
              if form_data.alternate_signer_full_name.present?
                pdf.text_box form_data.signature_of_alternate_signer,
                             default_text_opts.merge(form_fields.boxes[:signature_of_alternate_signer])
              else
                pdf.text_box form_data.signature_of_veteran_claimant_or_rep,
                             default_text_opts.merge(form_fields.boxes[:signature_of_veteran_claimant_or_rep])
              end

              fill_evidence_name_location_text pdf
              fill_new_evidence_dates pdf
            end
            tmp_path
          end
          # rubocop:enable Metrics/MethodLength

          def additional_pages?
            additional_issues? || additional_evidence_locations? || form_data.long_signature?
          end

          def additional_issues?
            form_data.contestable_issues.count > MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM
          end

          def additional_evidence_locations?
            form_data.new_evidence_locations.count > MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM
          end

          def fill_contestable_issues_text(pdf)
            issues = form_data.contestable_issues.take(MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM)
            issues.first(MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM).each_with_index do |issue, i|
              if issue.text_exists?
                pdf.text_box issue.text, default_text_opts.merge(form_fields.boxes[:contestable_issues][i])
                pdf.text_box issue.decision_date_string, default_text_opts.merge(form_fields.boxes[:decision_dates][i])
                pdf.text_box form_data.soc_date_text(issue), default_text_opts.merge(form_fields.boxes[:soc_dates][i])
              end
            end
          end

          def fill_evidence_name_location_text(pdf)
            locations = form_data.new_evidence_locations.take(MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM)

            locations.first(MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM).each_with_index do |location, i|
              pdf.text_box location, default_text_opts.merge(form_fields.boxes[:new_evidence_locations][i])
            end
          end

          def fill_new_evidence_dates(pdf)
            evidence_dates = form_data.new_evidence_dates.take(MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM)

            evidence_dates.first(MAX_NUMBER_OF_EVIDENCE_LOCATIONS_FORM).each_with_index do |dates, i|
              dates.each_with_index do |date, date_index|
                x, y = form_fields.boxes[:new_evidence_dates][i][:at]
                y_offset = y - date_index * 9
                date_opts = form_fields.boxes[:new_evidence_dates][i].merge({ at: [x, y_offset], size: 8 })

                pdf.text_box date, default_text_opts.merge(date_opts)
              end
            end
          end

          def whiteout(pdf, at:, width:, height: 14)
            pdf.fill_color 'ffffff'
            pdf.fill_rectangle at, width, height
            pdf.fill_color '000000'
          end

          def fill_text(pdf, attr, long_text_override: nil, length_for_override: SHORT_EMAIL_LENGTH)
            text = form_data.send(attr)

            return if text.blank?

            text = long_text_override if long_text_override.present? && text.length > length_for_override
            text_opts = form_fields.boxes[attr].merge(default_text_opts).merge(height: 13)

            whiteout pdf, **form_fields.boxes[attr]

            pdf.text_box text, text_opts
          end
        end
      end
    end
  end
end
