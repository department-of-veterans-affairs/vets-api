# frozen_string_literal: true

module AppealsApi
  class HigherLevelReviewPdfConstructor
    PDF_TEMPLATE = Rails.root.join('modules', 'appeals_api', 'config', 'pdfs')

    def initialize(higher_level_review_id)
      @hlr = AppealsApi::HigherLevelReview.find(higher_level_review_id)
    end

    def fill_pdf
      pdftk = PdfForms.new(Settings.binaries.pdftk)
      output_path = "/tmp/#{hlr.id}.pdf"
      pdftk.fill_form(
        "#{PDF_TEMPLATE}/200996.pdf",
        output_path,
        pdf_options,
        flatten: true
      )
      output_path
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def pdf_options
      options = {
        "F[0].#subform[2].VeteransFirstName[0]": hlr.first_name,
        "F[0].#subform[2].VeteransMiddleInitial1[0]": hlr.middle_initial,
        "F[0].#subform[2].VeteransLastName[0]": hlr.last_name,
        "F[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]": hlr.ssn.first(3),
        "F[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]": hlr.ssn[3..4],
        "F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]": hlr.ssn.last(4),
        "F[0].#subform[2].DOBmonth[0]": hlr.birth_mm,
        "F[0].#subform[2].DOBday[0]": hlr.birth_dd,
        "F[0].#subform[2].DOByear[0]": hlr.birth_yyyy,
        "F[0].#subform[2].VAFileNumber[0]": hlr.file_number,
        "F[0].#subform[2].VeteransServiceNumber[0]": hlr.service_number,
        "F[0].#subform[2].InsurancePolicyNumber[0]": hlr.insurance_policy_number,
        "F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]": hlr.number_and_street,
        "F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]": hlr.apt_unit_number,
        "F[0].#subform[2].CurrentMailingAddress_City[0]": hlr.city,
        "F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]": hlr.state_code,
        "F[0].#subform[2].CurrentMailingAddress_Country[0]": hlr.country_code,
        "F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": hlr.zip_code_5,
        "F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": hlr.zip_code_4,
        "F[0].#subform[2].TELEPHONE[0]": hlr.veteran_phone_number,
        "F[0].#subform[2].EMAIL[0]": hlr.email,
        "F[0].#subform[2].BenefitType[0]": hlr.benefit_type == 'nca' ? 9 : 'Off',
        "F[0].#subform[2].BenefitType[1]": hlr.benefit_type == 'vha' ? 6 : 'Off',
        "F[0].#subform[2].BenefitType[2]": hlr.benefit_type == 'education' ? 5 : 'Off',
        "F[0].#subform[2].BenefitType[3]": hlr.benefit_type == 'insurance' ? 8 : 'Off',
        "F[0].#subform[2].BenefitType[4]": hlr.benefit_type == 'loan_guaranty' ? 7 : 'Off',
        "F[0].#subform[2].BenefitType[5]": hlr.benefit_type == 'fiduciary' ? 4 : 'Off',
        "F[0].#subform[2].BenefitType[6]": hlr.benefit_type == 'voc_rehab' ? 3 : 'Off',
        "F[0].#subform[2].BenefitType[7]": hlr.benefit_type == 'pension_survivors_benefits' ? 2 : 'Off',
        "F[0].#subform[2].BenefitType[8]": hlr.benefit_type == 'compensation' ? 1 : 'Off',
        "F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]": hlr.same_office? ? 1 : 'Off',
        "F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]": hlr.informal_conference? ? 1 : 'Off',
        "F[0].#subform[2].TIME8TO10AM[0]": hlr.informal_conference_times.include?('800-1000 ET') ? 1 : 'Off',
        "F[0].#subform[2].TIME10TO1230PM[0]": hlr.informal_conference_times.include?('1000-1230 ET') ? 1 : 'Off',
        "F[0].#subform[2].TIME1230TO2PM[0]": hlr.informal_conference_times.include?('1230-1400 ET') ? 1 : 'Off',
        "F[0].#subform[2].TIME2TO430PM[0]": hlr.informal_conference_times.include?('1400-1630 ET') ? 1 : 'Off',
        "F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]": hlr.informal_conference_rep_name_and_phone_number,
        "F[0].#subform[3].SIGNATUREOFVETERANORCLAIMANT[0]": hlr.full_name,
        "F[0].#subform[3].DateSigned[0]": Time.zone.now.strftime('%m/%d/%Y')
      }
      hlr.contestable_issues.each_with_index do |issue, index|
        next if index >= 6

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
      end
      options
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    private

    attr_reader :hlr
  end
end
