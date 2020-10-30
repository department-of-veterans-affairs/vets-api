# frozen_string_literal: true

require 'central_mail/datestamp_pdf'
require_relative './base_pdf_constructor'

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
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def pdf_options
      return @pdf_options if @pdf_options

      options = {
          "F[0].Page_1[0].VeteransFirstName[0]": 'Test Name',
          #"F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]": '',
          #"F[0].Page_1[0].VAFileNumber[0]": '',
          "F[0].Page_1[0].DateSigned[0]": '2020-12-25', # Veterans DOB
          #"F[0].Page_1[0].ClaimantsFirstName[0]": '',
          #"F[0].Page_1[0].DateSigned[1]": '',
          #"F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]": '',
          #"F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[0]": '',
          #"F[0].Page_1[0].PreferredPhoneNumber[0]": '',
          #"F[0].Page_1[0].PreferredE_MailAddress[0]": '',
          #"F[0].Page_1[0].PreferredE_MailAddress[1]": '',
          #"F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[1]": '',
          #"F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[2]": '',
          #"F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[3]": '',
          #"F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[4]": '',
          #"F[0].Page_1[0].DecisionReviewOfficer_DROReviewProcess[5]": '',
          #"F[0].Page_1[0].Disagreement1[0]": '',
          #"F[0].Page_1[0].Percentage2[0]": '',
          #"F[0].Page_1[0].Disagreement2[0]": '',
          #"F[0].Page_1[0].Percentage2[1]": '',
          #"F[0].Page_1[0].Disagreement3[0]": '',
          #"F[0].Page_1[0].Percentage2[2]": '',
          #"F[0].Page_1[0].Disagreement2[1]": '',
          #"F[0].Page_1[0].Percentage2[3]": '',
          #"F[0].Page_1[0].Disagreement2[2]": '',
          #"F[0].Page_1[0].Percentage2[4]": '',
          #"F[0].Page_1[0].SignatureOfClaimant_AuthorizedRepresentative[0]": '',
          #"F[0].Page_1[0].DateSigned[2]": '',
      }
      @pdf_options = options
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
