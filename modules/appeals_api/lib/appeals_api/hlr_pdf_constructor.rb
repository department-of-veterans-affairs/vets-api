# frozen_string_literal: true

module AppealsApi
  class HlrPdfConstructor

    PDF_TEMPLATE = Rails.root.join('modules', 'appeals_api', 'config', 'pdfs')

    def initialize(higher_level_review_id)
      higher_level_review = AppealsApi::HigherLevelReviewSubmission.find(higher_level_review_id)
      @target_veteran = build_veteran(higher_level_review)
    end

    def build_veteran(higher_level_review)
      form_data = higher_level_review.form_data['data']['attributes']
      included = higher_level_review.form_data['included']
      auth_headers = higher_level_review.auth_headers
      OpenStruct.new(
        first_name: auth_headers['X-VA-First-Name'],
        middle_name: auth_headers['X-VA-Middle-Initial'],
        last_name: auth_headers['X-VA-Last-Name'],
        ssn: auth_headers['X-VA-SSN'],
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

    def pdf
      @pdf ||= FillablePDF.new "#{PDF_TEMPLATE}/200996.pdf"
    end

    def fill_pdf
      template = pdf
      template.set_field(:"F[0].#subform[2].VeteransFirstName[0]", @target_veteran.first_name)
      pdf.set_field(:"F[0].#subform[2].VeteransMiddleInitial1[0]", @target_veteran.middle_name.first)
      pdf.set_field(:"F[0].#subform[2].VeteransLastName[0]", @target_veteran.last_name)
      pdf.set_field(:"F[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]", @target_veteran.ssn.first(3))
      pdf.set_field(:"F[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]", @target_veteran.ssn[2..3])
      pdf.set_field(:"F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]", @target_veteran.ssn.last(4))
      pdf.set_field(:"F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]", @target_veteran.ssn.last(4))
      pdf.set_field(:"F[0].#subform[2].DOBmonth[0]", @target_veteran.birth_date.split('-')[1])
      pdf.set_field(:"F[0].#subform[2].DOBday[0]", @target_veteran.birth_date.split('-')[2])
      pdf.set_field(:"F[0].#subform[2].DOByear[0]", @target_veteran.birth_date.split('-')[0])

      #address

      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]", @target_veteran.address_line_1)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]", @target_veteran.address_line_2)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_City[0]", @target_veteran.city)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]", @target_veteran.state)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_Country[0]", @target_veteran.country)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]", @target_veteran.zip)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]", @target_veteran.zip_last_4)

      pdf.set_field(:"F[0].#subform[2].BenefitType[0]",  @target_veteran.benefit_type == 'nca' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[1]",  @target_veteran.benefit_type == 'vha' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[2]",  @target_veteran.benefit_type == 'education' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[3]",  @target_veteran.benefit_type == 'insurance' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[4]",  @target_veteran.benefit_type == 'loan_guaranty' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[5]",  @target_veteran.benefit_type == 'fiduciary' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[6]",  @target_veteran.benefit_type == 'voc_rehab' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[7]",  @target_veteran.benefit_type == 'pension_survivors_benefits' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[8]",  @target_veteran.benefit_type == 'compensation' ? 'On' : 'Off')

      pdf.set_field(:"F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]", @target_veteran.same_office ? 'On' : 'Off')

      pdf.set_field(:"F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]", @target_veteran.informal_conference ? 'On' : 'Off')

      pdf.set_field(:"F[0].#subform[2].TIME8TO10AM[0]", @target_veteran.conference_times.include?('800-1000 ET') ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].TIME10TO1230PM[0]", @target_veteran.conference_times.include?('1000-1230 ET') ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].TIME1230TO2PM[0]", @target_veteran.conference_times.include?('1230-1400 ET') ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].TIME2TO430PM[0]", @target_veteran.conference_times.include?('1400-1630 ET') ? 'On' : 'Off')

      pdf.set_field(:"F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]", @target_veteran.rep_contact_info)
      @target_veteran.issues.each_with_index do |issue, index|
        next if index >= 6
        if index == 0
          pdf.set_field(:"F[0].#subform[3].SPECIFICISSUE#{index + 1}[1]", issue['attributes']['issue'])
          pdf.set_field(:"F[0].#subform[3].DateofDecision[5]", issue['attributes']['decision_date'])
        elsif index == 1
          pdf.set_field(:"F[0].#subform[3].SPECIFICISSUE#{index}[0]", issue['attributes']['issue'])
          pdf.set_field(:"F[0].#subform[3].DateofDecision[#{index - 1}]", issue['attributes']['decisionDate'])
        else
          pdf.set_field(:"F[0].#subform[3].SPECIFICISSUE#{index + 1}[0]", issue['attributes']['issue'])
          pdf.set_field(:"F[0].#subform[3].DateofDecision[#{index - 1}]", issue['attributes']['decisionDate'])
        end
      end
      pdf.save_as("#{@target_veteran.ssn}_#{Time.now.to_i}_200996.pdf", flatten: true)
    end

  end
end

