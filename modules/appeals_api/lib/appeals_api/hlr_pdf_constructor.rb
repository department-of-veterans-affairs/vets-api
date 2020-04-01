# frozen_string_literal: true

module AppealsApi
  class HlrPdfConstructor

    PDF_TEMPLATE = Rails.root.join('modules', 'appeals_api', 'config', 'pdfs')

    def initialize(target_veteran)
      @target_veteran = target_veteran
    end

    def pdf
      @pdf ||= FillablePDF.new "#{PDF_TEMPLATE}/200996.pdf"
    end

    def fill_pdf
      pdf.set_field(:"F[0].#subform[2].VeteransFirstName[0]", @target_veteran.first_name)
      pdf.set_field(:"F[0].#subform[2].VeteransMiddleInitial1[0]", @target_veteran.middle_name.first)
      pdf.set_field(:"F[0].#subform[2].VeteransLastName[0]", @target_veteran.last_name)
      pdf.set_field(:"F[0].#subform[2].SocialSecurityNumber_FirstThreeNumbers[0]", @target_veteran.ssn.first(3))
      pdf.set_field(:"F[0].#subform[2].SocialSecurityNumber_SecondTwoNumbers[0]", @target_veteran.ssn[2..3])
      pdf.set_field(:"F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]", @target_veteran.ssn.last(4))
      pdf.set_field(:"F[0].#subform[2].SocialSecurityNumber_LastFourNumbers[0]", @target_veteran.ssn.last(4))
      pdf.set_field(:"F[0].#subform[2].DOBmonth[0]", @target_veteran.birth_date.month)
      pdf.set_field(:"F[0].#subform[2].DOBday[0]", @target_veteran.birth_date.day)
      pdf.set_field(:"F[0].#subform[2].DOByear[0]", @target_veteran.birth_date.year)
      # claimant
      pdf.set_field(:"F[0].#subform[2].ClaimantsFirstName[0]", @target_veteran.claimant_first_name)
      pdf.set_field(:"F[0].#subform[2].ClaimantsMiddleInitial1[0]", @target_veteran.claimant_middle_name.first)
      pdf.set_field(:"F[0].#subform[2].ClaimantsLastName[0]", @target_veteran.claimant_last_name)

      #address

      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_NumberAndStreet[0]", @target_veteran.address_1)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_ApartmentOrUnitNumber[0]", @target_veteran.address_2)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_City[0]", @target_veteran.city)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_StateOrProvince[0]", @target_veteran.state)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_Country[0]", @target_veteran.country)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]", @target_veteran.zip)
      pdf.set_field(:"F[0].#subform[2].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]", @target_veteran.zip_last_4)

      pdf.set_field(:"F[0].#subform[2].BenefitType[0]",  @target_veteran.benefit_type == 'national_cemetary_administration' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[1]",  @target_veteran.benefit_type == 'veteran_health_administration' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[2]",  @target_veteran.benefit_type == 'education' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[3]",  @target_veteran.benefit_type == 'insurance' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[4]",  @target_veteran.benefit_type == 'loan_guaranty' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[5]",  @target_veteran.benefit_type == 'fiduciary' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[6]",  @target_veteran.benefit_type == 'vocational_rehabilitation_and_employment' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[7]",  @target_veteran.benefit_type == 'pension_survivors_benefits' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].BenefitType[8]",  @target_veteran.benefit_type == 'compensation' ? 'On' : 'Off')

      pdf.set_field(:"F[0].#subform[2].HIGHERLEVELREVIEWCHECKBOX[0]", @target_veteran.same_office ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].INFORMALCONFERENCECHECKBOX[0]", @target_veteran.informal_conference ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].TIME8TO10AM[0]", @target_veteran.conference_time == '8am-10am' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].TIME10TO1230PM[0]", @target_veteran.conference_time =='10am-12:30pm' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].TIME1230TO2PM[0]", @target_veteran.conference_time =='12:30pm-2pm' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].TIME2TO430PM[0]", @target_veteran.conference_time =='2pm-4:30pm' ? 'On' : 'Off')
      pdf.set_field(:"F[0].#subform[2].REPRESENTATIVENAMEANDTELEPHONENUMBER[0]", @target_veteran.rep_contact_info)
      @target_veteran.issues.each_with_index do |issue, index|
        if index == 0
          pdf.set_field(:"F[0].#subform[3].SPECIFICISSUE#{index + 1}[1]", issue[:specific_issue])
          pdf.set_field(:"F[0].#subform[3].DateofDecision[5]", issue[:decision_date].strftime("%m/%d/%Y"))
        elsif index == 1
          pdf.set_field(:"F[0].#subform[3].SPECIFICISSUE#{index}[0]", issue[:specific_issue])
          pdf.set_field(:"F[0].#subform[3].DateofDecision[#{index -1}]", issue[:decision_date].strftime("%m/%d/%Y"))
        else
          pdf.set_field(:"F[0].#subform[3].SPECIFICISSUE#{index + 1}[0]", issue[:specific_issue])
          pdf.set_field(:"F[0].#subform[3].DateofDecision[#{index - 1}]", issue[:decision_date].strftime("%m/%d/%Y"))
        end
      end


      pdf.save_as("#{@target_veteran.ssn}_200996.pdf", flatten: true)

    end
  end
end

