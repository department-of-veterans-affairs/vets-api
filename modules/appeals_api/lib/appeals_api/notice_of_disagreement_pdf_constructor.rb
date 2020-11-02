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

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def pdf_options
      return @pdf_options if @pdf_options

      nod_pdf_options = AppealsApi::NoticeOfDisagreementPdfOptions.new(@appeal)

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
        "F[0].Page_1[0].PreferredE_MailAddress[0]": nod_pdf_options.email,
        "F[0].Page_1[0].PreferredE_MailAddress[1]": nod_pdf_options.representatives_name, # Representatives name
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[1]":
              nod_pdf_options.board_review_option == 'direct' ? 1 : 'Off',
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[2]":
              nod_pdf_options.board_review_option == 'evidence' ? 1 : 'Off',
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[3]":
              nod_pdf_options.board_review_option == 'hearing' ? 1 : 'Off',
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[4]":
              nod_pdf_options.contestable_issues.size > 5 ? 1 : 'Off', # Additional pages checkbox
        "F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[5]": nod_pdf_options.soc_opt_in? ? 1 : 'Off', # soc
        "F[0].Page_1[0].SignatureOfClaimant_AuthorizedRepresentative[0]": nod_pdf_options.signature, # Signature
        "F[0].Page_1[0].DateSigned[2]": nod_pdf_options.date_signed
      }

      nod_pdf_options.contestable_issues.each_with_index do |issue, index|
        if index < 5
          if index < 3
            options[:"F[0].Page_1[0].Disagreement#{index + 1}[0]"] = issue['attributes']['issue']
          else
            options[:"F[0].Page_1[0].Disagreement2[#{index - 2}]"] = issue['attributes']['issue']
          end
          options[:"F[0].Page_1[0].Percentage2[#{index}]"] = issue['attributes']['decisionDate']
        else
          text = "Issue: #{issue['attributes']['issue']} - Decision Date: #{issue['attributes']['decisionDate']}"
          options[:additional_page] = "#{text}\n#{options[:additional_page]}"
        end
      end

      @pdf_options = options
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
