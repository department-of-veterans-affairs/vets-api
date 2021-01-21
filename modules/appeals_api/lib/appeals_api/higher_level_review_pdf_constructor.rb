# frozen_string_literal: true

require 'central_mail/datestamp_pdf'
require_relative './base_pdf_constructor'

module AppealsApi
  class HigherLevelReviewPdfConstructor < BasePdfConstructor
    MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM = 6

    def initialize(higher_level_review_id)
      @higher_level_review_id = higher_level_review_id
    end

    def appeal
      @appeal ||= AppealsApi::HigherLevelReview.find(@higher_level_review_id)
    end

    def self.form_title
      '200996'
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def pdf_options
      return @pdf_options if @pdf_options

      options = {
        "F[0].#subform[2].VeteransFirstName[0]": appeal.first_name,
        "F[0].#subform[2].VeteransMiddleInitial1[0]": appeal.middle_initial,
        "F[0].#subform[2].VeteransLastName[0]": appeal.last_name,
        "F[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]": appeal.ssn.first(3),
        "F[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]": appeal.ssn[3..4],
        "F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]": appeal.ssn.last(4),
        "F[0].#subform[2].DOBmonth[0]": appeal.birth_mm,
        "F[0].#subform[2].DOBday[0]": appeal.birth_dd,
        "F[0].#subform[2].DOByear[0]": appeal.birth_yyyy,
        "F[0].#subform[2].VAFileNumber[0]": appeal.file_number,
        "F[0].#subform[2].VeteransServiceNumber[0]": appeal.service_number,
        "F[0].#subform[2].InsurancePolicyNumber[0]": appeal.insurance_policy_number,
        "F[0].#subform[2].ClaimantType[0]": 'off',
        "F[0].#subform[2].ClaimantType[1]": 'off',
        "F[0].#subform[2].ClaimantType[2]": 'off',
        "F[0].#subform[2].ClaimantType[3]": 'off',
        "F[0].#subform[2].ClaimantType[4]": 1, # veteran. Note: Ordering of array doesn't seem to match form
        "F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]": HigherLevelReview::NO_ADDRESS_PROVIDED_SENTENCE,
        "F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]": '',
        "F[0].#subform[2].CurrentMailingAddress_City[0]": '',
        "F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]": '',
        "F[0].#subform[2].CurrentMailingAddress_Country[0]": '',
        "F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": '',
        "F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": '',
        "F[0].#subform[2].TELEPHONE[0]": appeal.veteran_phone_number.presence ||
                                         HigherLevelReview::NO_PHONE_PROVIDED_SENTENCE,
        "F[0].#subform[2].EMAIL[0]": appeal.email.presence || HigherLevelReview::NO_EMAIL_PROVIDED_SENTENCE,
        "F[0].#subform[2].BenefitType[0]": appeal.benefit_type == 'nca' ? 9 : 'Off',
        "F[0].#subform[2].BenefitType[1]": appeal.benefit_type == 'vha' ? 6 : 'Off',
        "F[0].#subform[2].BenefitType[2]": appeal.benefit_type == 'education' ? 5 : 'Off',
        "F[0].#subform[2].BenefitType[3]": appeal.benefit_type == 'insurance' ? 8 : 'Off',
        "F[0].#subform[2].BenefitType[4]": appeal.benefit_type == 'loan_guaranty' ? 7 : 'Off',
        "F[0].#subform[2].BenefitType[5]": appeal.benefit_type == 'fiduciary' ? 4 : 'Off',
        "F[0].#subform[2].BenefitType[6]": appeal.benefit_type == 'voc_rehab' ? 3 : 'Off',
        "F[0].#subform[2].BenefitType[7]": appeal.benefit_type == 'pension_survivors_benefits' ? 2 : 'Off',
        "F[0].#subform[2].BenefitType[8]": appeal.benefit_type == 'compensation' ? 1 : 'Off',
        "F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]": appeal.same_office? ? 1 : 'Off',
        "F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]": appeal.informal_conference? ? 1 : 'Off',
        "F[0].#subform[2].TIME8TO10AM[0]": appeal.informal_conference_times.include?('800-1000 ET') ? 1 : 'Off',
        "F[0].#subform[2].TIME10TO1230PM[0]": appeal.informal_conference_times.include?('1000-1230 ET') ? 1 : 'Off',
        "F[0].#subform[2].TIME1230TO2PM[0]": appeal.informal_conference_times.include?('1230-1400 ET') ? 1 : 'Off',
        "F[0].#subform[2].TIME2TO430PM[0]": appeal.informal_conference_times.include?('1400-1630 ET') ? 1 : 'Off',
        "F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]": appeal
                .informal_conference_rep_name_and_phone_number,
        "F[0].#subform[3].SIGNATUREOFVETERANORCLAIMANT[0]": appeal.full_name,
        "F[0].#subform[3].DateSigned[0]": appeal.date_signed
      }

      appeal.contestable_issues.each_with_index do |issue, index|
        if index < MAX_NUMBER_OF_ISSUES_ON_MAIN_FORM
          if index.zero?
            options[:"F[0].#subform[3].SPECIFICISSUE#{index + 1}[1]"] = issue['attributes']['issue']
            options[:'F[0].#subform[3].DateofDecision[5]'] = issue['attributes']['decisionDate']
          elsif index == 1
            options[:"F[0].#subform[3].SPECIFICISSUE#{index}[0]"] = issue['attributes']['issue']
            options[:"F[0].#subform[3].DateofDecision[#{index - 1}]"] = issue['attributes']['decisionDate']
          else
            options[:"F[0].#subform[3].SPECIFICISSUE#{index + 1}[0]"] = issue['attributes']['issue']
            options[:"F[0].#subform[3].DateofDecision[#{index - 1}]"] = issue['attributes']['decisionDate']
          end
        else
          text = "Issue: #{issue['attributes']['issue']} - Decision Date: #{issue['attributes']['decisionDate']}"
          options[:additional_pages] = "#{text}\n#{options[:additional_pages]}"
        end
      end
      @pdf_options = options
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
