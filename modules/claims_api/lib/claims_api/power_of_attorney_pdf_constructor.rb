# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyPdfConstructor
    def initialize(power_of_attorney_id)
      @power_of_attorney = ClaimsApi::PowerOfAttorney.find power_of_attorney_id
    end

    def fill_pdf(pdf_path, page)
      pdftk = PdfForms.new(Settings.binaries.pdftk)
      temp_path = Rails.root.join('tmp', "poa_#{Time.now.to_i}_page_#{page}.pdf")
      pdftk.fill_form(
        pdf_path,
        temp_path,
        page == 1 ? page_1_options : page_2_options,
        flatten: true
      )
      temp_path
    end

    def data
      @power_of_attorney.form_data
    end

    def auth_headers
      @power_of_attorney.auth_headers
    end

    def page_2_options
      base_form = 'form1[0].#subform[1]'
      {
        "#{base_form}.SocialSecurityNumber_FirstThreeNumbers[1]": auth_headers['va_eauth_pnid'][0..2],
        "#{base_form}.SocialSecurityNumber_SecondTwoNumbers[1]": auth_headers['va_eauth_pnid'][3..4],
        "#{base_form}.SocialSecurityNumber_LastFourNumbers[1]": auth_headers['va_eauth_pnid'][5..9],
        "#{base_form}.AuthorizationForRepAccessToRecords[0]": data['recordConcent'] == true ? 1 : 0,
        "#{base_form}.AuthorizationForRepActClaimantsBehalf[0]": data['consentAddressChange'] == true ? 1 : 0,
        "#{base_form}.Date_Signed[0]": I18n.l(Time.zone.now.to_date, format: :va_form),
        "#{base_form}.Date_Signed[1]": I18n.l(Time.zone.now.to_date, format: :va_form),
        "#{base_form}.LIMITATIONOFCONSENT[0]": data['consentLimits']&.join(', ')
      }
    end

    # rubocop:disable Layout/LineLength
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    def page_1_options
      base_form = 'form1[0].#subform[0]'
      {
        # Veteran
        "#{base_form}.VeteransLastName[0]": auth_headers['va_eauth_lastName'],
        "#{base_form}.VeteransFirstName[0]": auth_headers['va_eauth_firstName'],
        "#{base_form}.TelephoneNumber_IncludeAreaCode[0]": "#{data.dig('veteran', 'phone', 'areaCode')} #{data.dig('veteran', 'phone', 'phoneNumber')}",
        "#{base_form}.SocialSecurityNumber_FirstThreeNumbers[0]": auth_headers['va_eauth_pnid'][0..2],
        "#{base_form}.SocialSecurityNumber_SecondTwoNumbers[0]": auth_headers['va_eauth_pnid'][3..4],
        "#{base_form}.SocialSecurityNumber_LastFourNumbers[0]": auth_headers['va_eauth_pnid'][5..9],
        "#{base_form}.DOBmonth[0]": auth_headers['va_eauth_birthdate'].split('-').second,
        "#{base_form}.DOBday[0]": auth_headers['va_eauth_birthdate'].split('-').last.first(2),
        "#{base_form}.DOByear[0]": auth_headers['va_eauth_birthdate'].split('-').first,
        "#{base_form}.Veterans_MailingAddress_NumberAndStreet[0]": data.dig('veteran', 'address', 'numberAndStreet'),
        "#{base_form}.MailingAddress_ApartmentOrUnitNumber[1]": data.dig('veteran', 'address', 'aptUnitNumber'),
        "#{base_form}.MailingAddress_City[1]": data.dig('veteran', 'address', 'city'),
        "#{base_form}.MailingAddress_StateOrProvince[1]": data.dig('veteran', 'address', 'state'),
        "#{base_form}.MailingAddress_Country[1]": data.dig('veteran', 'address', 'country'),
        "#{base_form}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": data.dig('veteran', 'address', 'zipFirstFive'),
        "#{base_form}.MailingAddress_ZIPOrPostalCode_ZIPOrPostalCode_LastFourNumbers[1]": data.dig('veteran', 'address', 'zipLastFour'),

        # Service Branch
        "#{base_form}.ARMYCheckbox1[0]": (data.dig('veteran', 'serviceBranch') == 'ARMY' ? 1 : 0),
        "#{base_form}.NAVYCheckbox2[0]": (data.dig('veteran', 'serviceBranch') == 'NAVY' ? 1 : 0),
        "#{base_form}.AIR_FORCECheckbox3[0]": (data.dig('veteran', 'serviceBranch') == 'AIR FORCE' ? 1 : 0),
        "#{base_form}.MARINE_CORPSCheckbox4[0]": (data.dig('veteran', 'serviceBranch') == 'MARINE CORPS' ? 1 : 0),
        "#{base_form}.COAST_GUARDCheckbox5[0]": (data.dig('veteran', 'serviceBranch') == 'COAST GUARD' ? 1 : 0),
        "#{base_form}.OTHER_Checkbox6[0]": (data.dig('veteran', 'serviceBranch') == 'OTHER' ? 1 : 0),
        "#{base_form}.JF15[0]": data.dig('veteran', 'serviceBranchOther'),

        # Claimant
        "#{base_form}.Claimants_First_Name[0]": data.dig('claimant', 'firstName'),
        "#{base_form}.Claimants_Last_Name[0]": data.dig('claimant', 'lastName'),
        "#{base_form}.Claimants_Middle_Initial1[0]": data.dig('claimant', 'middleInitial'),
        "#{base_form}.MailingAddress_NumberAndStreet[0]": data.dig('claimant', 'address', 'numberAndStreet'),
        "#{base_form}.MailingAddress_ApartmentOrUnitNumber[0]": data.dig('claimant', 'address', 'aptUnitNumber'),
        "#{base_form}.MailingAddress_City[0]": data.dig('claimant', 'address', 'city'),
        "#{base_form}.MailingAddress_StateOrProvince[0]": data.dig('claimant', 'address', 'state'),
        "#{base_form}.MailingAddress_Country[0]": data.dig('claimant', 'address', 'country'),
        "#{base_form}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": data.dig('claimant', 'address', 'zipFirstFive'),
        "#{base_form}.MailingAddress_ZIPOrPostalCode_ZIPOrPostalCode_LastFourNumbers[0]": data.dig('address', 'zipLastFour'),
        "#{base_form}.TelephoneNumber_IncludeAreaCode[1]": "#{data.dig('claimant', 'phone', 'areaCode')} #{data.dig('claimant', 'phone', 'phoneNumber')}",
        "#{base_form}.EmailAddress_Optional[1]": data.dig('claimant', 'email'),
        "#{base_form}.RelationshipToVeteran[0]": data.dig('claimant', 'relationship'),

        "#{base_form}.NAME_OF_INDIVIDUAL_APPOINTED_AS_REPRESENTATIVE[0]": "#{data.dig('serviceOrganization', 'firstName')} #{data.dig('serviceOrganization', 'lastName')}",
        "#{base_form}.Checkbox3[0]": 1,
        "#{base_form}.ADDRESSOFINDIVIDUALAPPOINTEDASCLAIMANTSREPRESENTATATIVE[0]": stringify_address(data.dig('serviceOrganization', 'address')),
        "#{base_form}.SpecifyOrganization[0]": data.dig('serviceOrganization', 'organizationName'),

        "#{base_form}.Date_Of_Signature[0]": I18n.l(Time.zone.now.to_date, format: :va_form),
        "#{base_form}.Date_Of_Signature[1]": I18n.l(Time.zone.now.to_date, format: :va_form)
      }
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Layout/LineLength

    def stringify_address(address)
      "#{address['numberAndStreet']}, #{address['city']} #{address['state']} #{address['zipFirstFive']}"
    end
  end
end
