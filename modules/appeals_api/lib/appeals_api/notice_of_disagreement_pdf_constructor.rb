# frozen_string_literal: true

require 'central_mail/datestamp_pdf'
require_relative './base_pdf_constructor'
require_relative './notice_of_disagreement_pdf_options'

module AppealsApi
  class NoticeOfDisagreementPdfConstructor < BasePdfConstructor
    def initialize(notice_of_disagreement_id)
      @notice_of_disagreement_id = notice_of_disagreement_id
    end

    def appeal
      @appeal ||= AppealsApi::NoticeOfDisagreement.find(@notice_of_disagreement_id)
    end

    def self.form_title
      '10182'
    end

    def nod_pdf_options
      @nod_pdf_options ||= AppealsApi::NoticeOfDisagreementPdfOptions.new(@appeal)
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/AbcSize
    def pdf_options
      return @pdf_options if @pdf_options

      options = {
        "F[0].Page_1[0].VeteransFirstName[0]": nod_pdf_options.veteran_name,
        "F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]": nod_pdf_options.veteran_ssn,
        "F[0].Page_1[0].VAFileNumber[0]": nod_pdf_options.veteran_file_number,
        "F[0].Page_1[0].DateSigned[0]": nod_pdf_options.veteran_dob, # Veterans DOB
        "F[0].Page_1[0].ClaimantsFirstName[0]": nod_pdf_options.claimant_name,
        "F[0].Page_1[0].DateSigned[1]": nod_pdf_options.claimant_dob, # Claimant DOB
        "F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]": nod_pdf_options.address,
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[0]": nod_pdf_options.homeless? ? 1 : 'Off', # Homeless
        "F[0].Page_1[0].PreferredPhoneNumber[0]": nod_pdf_options.phone,
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[1]":
            nod_pdf_options.board_review_option == 'direct_review' ? 1 : 'Off',
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[2]":
            nod_pdf_options.board_review_option == 'evidence_submission' ? 1 : 'Off',
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[3]":
            nod_pdf_options.board_review_option == 'hearing' ? 1 : 'Off',
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[4]":
            nod_pdf_options.contestable_issues.size > 5 ? 1 : 'Off', # Additional pages checkbox
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[5]": nod_pdf_options.soc_opt_in? ? 1 : 'Off', # soc
        "F[0].Page_1[0].SignatureOfClaimant_AuthorizedRepresentative[0]": nod_pdf_options.signature, # Signature
        "F[0].Page_1[0].DateSigned[2]": nod_pdf_options.date_signed
      }

      # Fill in issue dates. The issue details are added by #insert_manual_fields
      nod_pdf_options.contestable_issues.take(5).each_with_index do |issue, index|
        options[:"F[0].Page_1[0].Percentage2[#{index}]"] = issue['attributes']['decisionDate']
      end

      insert_extra_issues_page(options) if nod_pdf_options.contestable_issues.size > 5

      @pdf_options = options
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/AbcSize

    # For inserting items into the pdf that require special insertion (e.g. where fields cannot hold enough text)
    def insert_manual_fields(pdf_template)
      pdftk = PdfForms.new(Settings.binaries.pdftk)
      temp_file = "#{::Common::FileHelpers.random_file_path}.pdf"
      output_path = "#{pdf_template}-final.pdf"

      Prawn::Document.generate(temp_file) do |pdf|
        text_opts = { overflow: :shrink_to_fit, min_font_size: 8, valign: :bottom }
        pdf.font 'Courier'
        pdf.text_box nod_pdf_options.email.to_s, text_opts.merge(at: [145, 510], width: 195, height: 20)
        pdf.text_box nod_pdf_options.representatives_name.to_s, text_opts.merge(at: [350, 510], width: 195, height: 20)
        nod_pdf_options.contestable_issues.take(5).each_with_index do |issue, index|
          ypos = 288 - (45 * index)
          pdf.text_box issue['attributes']['issue'],
                       text_opts.merge(at: [0, ypos], width: 444, height: 38, valign: :top)
        end
        2.times { pdf.start_new_page } # temp file and pdf template must have same num of pages for pdftk.multistamp
      end

      pdftk.multistamp(pdf_template, temp_file, output_path)
      output_path
    end

    def insert_extra_issues_page(pdf_options)
      # The first five issues are given space on the form, so drop them.
      # Reverse the order since :additional_page pdf options tends to write to the page in reverse order.
      # e.g. without the reversal, [6,7,8] would place Issue 8 at top of the page.
      nod_pdf_options.contestable_issues.drop(5).reverse.each do |issue|
        text = "Issue: #{issue['attributes']['issue']} - Decision Date: #{issue['attributes']['decisionDate']}"
        pdf_options[:additional_page] = "#{text}\n#{pdf_options[:additional_page]}"
      end
    end
  end
end
