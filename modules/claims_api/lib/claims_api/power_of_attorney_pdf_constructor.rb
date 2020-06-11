# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyPdfConstructor

    def initialize(power_of_attorney_id)
      @power_of_attorney = ClaimsApi::PowerOfAttorney.find power_of_attorney_id
    end

    def fill_pdf(pdf_path)
      pdftk = PdfForms.new(Settings.binaries.pdftk)
      temp_path = "#{Rails.root}/tmp/poa_#{Time.now.to_i}.pdf"
      puts temp_path
      pdftk.fill_form(
        pdf_path,
        temp_path,
        pdf_options,
        flatten: true
      )
    end

    def data
      @power_of_attorney.form_data
    end

    def auth_headers
      @power_of_attorney.auth_headers
    end

    def pdf_options
      {
        "form1[0].#subform[0].VeteransLastName[0]": auth_headers['va_eauth_lastName'],
        "form1[0].#subform[0].VeteransFirstName[0]": auth_headers['va_eauth_firstName'],
        "form1[0].#subform[0].TelephoneNumber_IncludeAreaCode[0]": "#{data.dig('phone', 'areaCode')} #{data.dig('phone', 'phoneNumber')}",
        'form1[0].#subform[0].SocialSecurityNumber_FirstThreeNumbers[0]': auth_headers['va_eauth_pnid'][0..2],
        'form1[0].#subform[0].SocialSecurityNumber_SecondTwoNumbers[0]': auth_headers['va_eauth_pnid'][3..4],
        'form1[0].#subform[0].SocialSecurityNumber_LastFourNumbers[0]': auth_headers['va_eauth_pnid'][5..9],
        'form1[0].#subform[0].DOBmonth[0]': auth_headers['va_eauth_birthdate'].split('-').second,
        'form1[0].#subform[0].DOBday[0]': auth_headers['va_eauth_birthdate'].split('-').last.first(2),
        'form1[0].#subform[0].DOByear[0]': auth_headers['va_eauth_birthdate'].split('-').first,
        'form1[0].#subform[0].Veterans_MailingAddress_NumberAndStreet[0]': data.dig('mailingAddress', 'numberAndStreet'),
        'form1[0].#subform[0].MailingAddress_ApartmentOrUnitNumber[1]': data.dig('mailingAddress', 'aptUnitNumber'),
        'form1[0].#subform[0].MailingAddress_City[1]': data.dig('mailingAddress', 'city'),
        'form1[0].#subform[0].MailingAddress_StateOrProvince[1]': data.dig('mailingAddress', 'state'),
        'form1[0].#subform[0].MailingAddress_Country[1]': data.dig('mailingAddress', 'country'),
        'form1[0].#subform[0].MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]': data.dig('mailingAddress', 'zipFirstFive'),
        'form1[0].#subform[0].MailingAddress_ZIPOrPostalCode_ZIPOrPostalCode_LastFourNumbers[1]': data.dig('mailingAddress', 'zipLastFour'),

        'form1[0].#subform[0].Claimants_First_Name[0]': data.dig('claimant', 'firstName'),
        'form1[0].#subform[0].Claimants_Last_Name[0]': data.dig('claimant', 'lastName'),
        'form1[0].#subform[0].Claimants_Middle_Initial1[0]': data.dig('claimant', 'middleInitial'),
        'form1[0].#subform[0].MailingAddress_NumberAndStreet[0]': data.dig('claimant', 'address', 'numberAndStreet'),
        'form1[0].#subform[0].MailingAddress_ApartmentOrUnitNumber[0]': data.dig('claimant', 'address', 'aptUnitNumber'),
        'form1[0].#subform[0].MailingAddress_City[0]': data.dig('claimant', 'address', 'city'),
        'form1[0].#subform[0].MailingAddress_StateOrProvince[0]': data.dig('claimant', 'address', 'state'),
        'form1[0].#subform[0].MailingAddress_Country[0]': data.dig('claimant', 'address', 'country'),
        'form1[0].#subform[0].MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]': data.dig('claimant', 'address', 'zipFirstFive'),
        'form1[0].#subform[0].MailingAddress_ZIPOrPostalCode_ZIPOrPostalCode_LastFourNumbers[0]': data.dig('address', 'zipLastFour'),
        'form1[0].#subform[0].TelephoneNumber_IncludeAreaCode[1]': "#{data.dig('claimant', 'phone', 'areaCode')} #{data.dig('claimant', 'phone', 'phoneNumber')}",
        'form1[0].#subform[0].EmailAddress_Optional[1]': data.dig('claimant', 'email'),
        'form1[0].#subform[0].RelationshipToVeteran[0]': data.dig('claimant', 'relationship'),

        'form1[0].#subform[0].NAME_OF_INDIVIDUAL_APPOINTED_AS_REPRESENTATIVE[0]': "#{data.dig('serviceOrganization', 'firstName')} #{data.dig('serviceOrganization', 'lastName')}",
        'form1[0].#subform[0].Checkbox3[0]': 1,
        'form1[0].#subform[0].ADDRESSOFINDIVIDUALAPPOINTEDASCLAIMANTSREPRESENTATATIVE[0]': stringify_address(data.dig('serviceOrganization', 'address')),
        'form1[0].#subform[0].SpecifyOrganization[0]': data.dig('serviceOrganization', 'organizationName'),

        'form1[0].#subform[0].Date_Of_Signature[0]': I18n.l(Time.zone.now.to_date, format: :va_form),
        'form1[0].#subform[0].Date_Of_Signature[1]': I18n.l(Time.zone.now.to_date, format: :va_form)
      }
    end

    def stringify_address(address_hash)
      "#{address_hash['numberAndStreet']}, #{address_hash['city']} #{address_hash['state']} #{address_hash['zipFirstFive']}"
    end
  end
end
