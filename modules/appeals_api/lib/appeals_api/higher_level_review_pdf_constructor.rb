# frozen_string_literal: true

module AppealsApi
  class HigherLevelReviewPdfConstructor
    PDF_TEMPLATE = Rails.root.join('modules', 'appeals_api', 'config', 'pdfs')

    def initialize(higher_level_review_id)
      @higher_level_review = AppealsApi::HigherLevelReview.find(higher_level_review_id)
      veteran
    end

    def veteran
      @veteran ||= build_veteran(@higher_level_review)
    end

    # rubocop:disable Metrics/MethodLength
    def build_veteran(higher_level_review)
      form_data = higher_level_review.form_data['data']['attributes']
      included = higher_level_review.form_data['included']
      auth_headers = higher_level_review.auth_headers
      OpenStruct.new(
        first_name: auth_headers['X-VA-First-Name'],
        middle_name: auth_headers['X-VA-Middle-Initial'],
        last_name: auth_headers['X-VA-Last-Name'],
        ssn: auth_headers['X-VA-SSN'],
        va_file_number: auth_headers['X-VA-File-Number'],
        service_number: auth_headers['X-VA-Service-Number'],
        insurance_policy_number: auth_headers['X-VA-Insurance-Policy-Number'],
        birth_date: auth_headers['X-VA-Birth-Date'],
        address_line_1: form_data.dig('veteran', 'address', 'addressLine1'),
        address_line_2: form_data.dig('veteran', 'address', 'addressLine2'),
        city: form_data.dig('veteran', 'address', 'city'),
        state: form_data.dig('veteran', 'address', 'stateCode'),
        country: form_data.dig('veteran', 'address', 'country'),
        zip: form_data.dig('veteran', 'address', 'zipCode'),
        zip_last_4: form_data.dig('veteran', 'address', 'zip_last_4'),
        benefit_type: form_data['benefitType'],
        same_office: form_data['sameOffice'],
        informal_conference: form_data['informalConference'],
        conference_times: form_data['informalConferenceTimes'],
        issues: included
      )
    end
    # rubocop:enable Metrics/MethodLength

    def fill_pdf
      pdftk = PdfForms.new(Settings.binaries.pdftk)
      output_path = "/tmp/#{@higher_level_review.id}.pdf"
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
        "F[0].#subform[2].VeteransFirstName[0]": @veteran.first_name,
        "F[0].#subform[2].VeteransMiddleInitial1[0]": @veteran.middle_name.first,
        "F[0].#subform[2].VeteransLastName[0]": @veteran.last_name,
        "F[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]": @veteran.ssn.first(3),
        "F[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]": @veteran.ssn[2..3],
        "F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]": @veteran.ssn.last(4),
        "F[0].#subform[2].DOBmonth[0]": @veteran.birth_date.split('-')[1],
        "F[0].#subform[2].DOBday[0]": @veteran.birth_date.split('-')[2],
        "F[0].#subform[2].DOByear[0]": @veteran.birth_date.split('-')[0],
        "F[0].#subform[2].VAFileNumber[0]": @veteran.va_file_number,
        "F[0].#subform[2].VeteransServiceNumber[0]": @veteran.service_number,
        "F[0].#subform[2].InsurancePolicyNumber[0]": @veteran.insurance_policy_number,

        "F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]": @veteran.address_line_1,
        "F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]": @veteran.address_line_2,
        "F[0].#subform[2].CurrentMailingAddress_City[0]": @veteran.city,
        "F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]": @veteran.state,
        "F[0].#subform[2].CurrentMailingAddress_Country[0]": @veteran.country,
        "F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": @veteran.zip,
        "F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": @veteran.zip_last_4,
        "F[0].#subform[2].BenefitType[0]": @veteran.benefit_type == 'nca' ? 9 : 'Off',
        "F[0].#subform[2].BenefitType[1]": @veteran.benefit_type == 'vha' ? 6 : 'Off',
        "F[0].#subform[2].BenefitType[2]": @veteran.benefit_type == 'education' ? 5 : 'Off',
        "F[0].#subform[2].BenefitType[3]": @veteran.benefit_type == 'insurance' ? 8 : 'Off',
        "F[0].#subform[2].BenefitType[4]": @veteran.benefit_type == 'loan_guaranty' ? 7 : 'Off',
        "F[0].#subform[2].BenefitType[5]": @veteran.benefit_type == 'fiduciary' ? 4 : 'Off',
        "F[0].#subform[2].BenefitType[6]": @veteran.benefit_type == 'voc_rehab' ? 3 : 'Off',
        "F[0].#subform[2].BenefitType[7]": @veteran.benefit_type == 'pension_survivors_benefits' ? 2 : 'Off',
        "F[0].#subform[2].BenefitType[8]": @veteran.benefit_type == 'compensation' ? 1 : 'Off',
        "F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]": @veteran.same_office ? 1 : 'Off',
        "F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]": @veteran.informal_conference ? 1 : 'Off',
        "F[0].#subform[2].TIME8TO10AM[0]": @veteran.conference_times.include?('800-1000 ET') ? 1 : 'Off',
        "F[0].#subform[2].TIME10TO1230PM[0]": @veteran.conference_times.include?('1000-1230 ET') ? 1 : 'Off',
        "F[0].#subform[2].TIME1230TO2PM[0]": @veteran.conference_times.include?('1230-1400 ET') ? 1 : 'Off',
        "F[0].#subform[2].TIME2TO430PM[0]": @veteran.conference_times.include?('1400-1630 ET') ? 1 : 'Off',
        "F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]": @veteran.rep_contact_info
      }
      @veteran.issues.each_with_index do |issue, index|
        next if index >= 6

        if index.zero?
          options["F[0].#subform[3].SPECIFICISSUE#{index + 1}[1]"] = issue['attributes']['issue']
          options['F[0].#subform[3].DateofDecision[5]'] = issue['attributes']['decisionDate']
        elsif index == 1
          options["F[0].#subform[3].SPECIFICISSUE#{index}[0]"] = issue['attributes']['issue']
          options["F[0].#subform[3].DateofDecision[#{index - 1}]"] = issue['attributes']['decisionDate']
        else
          options["F[0].#subform[3].SPECIFICISSUE#{index + 1}[0]"] = issue['attributes']['issue']
          options["F[0].#subform[3].DateofDecision[#{index - 1}]"] = issue['attributes']['decisionDate']
        end
      end
      options
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
