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
    def pdf_options
      options = {
        "VeteransFirstName[0]": hlr.first_name,
        "VeteransMiddleInitial1[0]": hlr.middle_initial,
        "VeteransLastName[0]": hlr.last_name,
        "SocialSecurityNumber_FirstThreeNumbers[0]": hlr.ssn.first(3),
        "SocialSecurityNumber_SecondTwoNumbers[0]": hlr.ssn[2..3],
        "SocialSecurityNumber_LastFourNumbers[0]": hlr.ssn.last(4),
        "DOBmonth[0]": hlr.birth_mm,
        "DOBday[0]": hlr.birth_dd,
        "DOByear[0]": hlr.birth_yyyy,
        "VAFileNumber[0]": hlr.file_number,
        "VeteransServiceNumber[0]": hlr.service_number,
        "InsurancePolicyNumber[0]": hlr.insurance_policy_number,

        "CurrentMailingAddress_NumberAndStreet[0]": hlr.number_and_street,
        "CurrentMailingAddress_ApartmentOrUnitNumber[0]": hlr.apt_unit_number,
        "CurrentMailingAddress_City[0]": hlr.city,
        "CurrentMailingAddress_StateOrProvince[0]": hlr.state_code,
        "CurrentMailingAddress_Country[0]": hlr.country_code,
        "CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": hlr.zip_code_5,
        "CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": hlr.zip_code_4,
        "BenefitType[0]": switch(benefit_type?('nca'), 9),
        "BenefitType[1]": switch(benefit_type?('vha'), 6),
        "BenefitType[2]": switch(benefit_type?('education'), 5),
        "BenefitType[3]": switch(benefit_type?('insurance'), 8),
        "BenefitType[4]": switch(benefit_type?('loan_guaranty'), 7),
        "BenefitType[5]": switch(benefit_type?('fiduciary'), 4),
        "BenefitType[6]": switch(benefit_type?('voc_rehab'), 3),
        "BenefitType[7]": switch(benefit_type?('pension_survivors_benefits'), 2),
        "BenefitType[8]": switch(benefit_type?('compensation'), 1),
        "HIGHERLEVELREVIEWCHECKBOX[0]": switch(hlr.same_office?),
        "INFORMALCONFERENCECHECKBOX[0]": switch(hlr.informal_conference?),
        "TIME8TO10AM[0]": switch(hlr.informal_conference_times.include?('800-1000 ET')),
        "TIME10TO1230PM[0]": switch(hlr.informal_conference_times.include?('1000-1230 ET')),
        "TIME1230TO2PM[0]": switch(hlr.informal_conference_times.include?('1230-1400 ET')),
        "TIME2TO430PM[0]": switch(hlr.informal_conference_times.include?('1400-1630 ET')),
        "REPRESENTATIVENAMEANDTELEPHONENUMBER[0]": hlr.informal_conference_rep_name_and_phone
      }.reduce({}) do |acc, (key, val)|
        acc.merge("#{subform 2}#{key}": val)
      end

      hlr.contestable_issues.each_with_index do |contestable_issue, index|
        issue = contestable_issue['attributes']['issue']
        decision_date = contestable_issue['attributes']['decisionDate']

        if index.zero?
          options["#{subform 3}SPECIFICISSUE#{index + 1}[1]"] = issue
          options["#{subform 3}DateofDecision[5]"] = decision_date
        elsif index == 1
          options["#{subform 3}SPECIFICISSUE#{index}[0]"] = issue
          options["#{subform 3}DateofDecision[#{index - 1}]"] = decision_date
        else
          options["#{subform 3}SPECIFICISSUE#{index + 1}[0]"] = issue
          options["#{subform 3}DateofDecision[#{index - 1}]"] = decision_date
        end
      end
      options
    end

    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    private

    attr_reader :hlr

    def subform(index)
      "F[0].#subform[#{index}]."
    end

    def switch(bool, on = 1, off = 'Off')
      bool ? on : off
    end

    def benefit_type?(type)
      hlr.benefit_type == type
    end
  end
end
