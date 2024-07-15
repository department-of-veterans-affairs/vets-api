# frozen_string_literal: true

module RepresentationManagement
  module V0
    module PdfConstructor
      class Form2122a < RepresentationManagement::V0::PdfConstructor::Base
        protected

        def template_path
          Rails.root.join('modules',
                          'representation_management',
                          'lib',
                          'representation_management',
                          'pdf_constructor',
                          'pdf_templates',
                          '21-22a.pdf')
        end

        #
        # Set the template path that will be used by the base class.
        #
        # @param data [Hash] Hash of data to add to the pdf
        def set_template_path
          @template_path = template_path
        end

        def page2_options(data)
          page2_key = 'form1[0].#subform[1]'
          {
            # Header
            # "#{page2_key}.SocialSecurityNumber_FirstThreeNumbers[1]": data.dig('veteran', 'ssn')[0..2],
            # "#{page2_key}.SocialSecurityNumber_SecondTwoNumbers[1]": data.dig('veteran', 'ssn')[3..4],
            # "#{page2_key}.SocialSecurityNumber_LastFourNumbers[1]": data.dig('veteran', 'ssn')[5..8],
            # # Section IV
            # # Item 19
            # "#{page2_key}.AuthorizationForRepAccessToRecords[0]": data['recordConsent'] == true ? 1 : 0,
            # # Item 20
            # "#{page2_key}.LIMITATIONOFCONSENT[0]": data['consentLimits']&.join(', ')&.gsub('_', ' '),
            # # Item 21
            # "#{page2_key}.AuthorizationForRepActClaimantsBehalf[0]": data['consentAddressChange'] == true ? 1 : 0,
            # # Conditions of Appointment
            # # Item 22B
            # "#{page2_key}.Date_Signed[0]": I18n.l(Time.zone.now.to_date, format: :va_form),
            # # Item 23
            # "#{page2_key}.LIMITATIONS[0]": data['conditionsOfAppointment']&.join(', '),
            # # Item 24B
            # "#{page2_key}.Date_Signed[1]": I18n.l(Time.zone.now.to_date, format: :va_form)
          }
        end

        # rubocop:disable Layout/LineLength
        def template_options(data)
          page1_key = 'form1[0].#subform[0]'
          {
            # Section !
            # Item 1
            "#{page1_key}.VeteransLastName[0]": data.veteran_last_name
            # "#{page1_key}.VeteransFirstName[0]": data.dig('veteran', 'firstName'),
            # # Item 2
            # "#{page1_key}.SocialSecurityNumber_FirstThreeNumbers[0]": data.dig('veteran', 'ssn')[0..2],
            # "#{page1_key}.SocialSecurityNumber_SecondTwoNumbers[0]": data.dig('veteran', 'ssn')[3..4],
            # "#{page1_key}.SocialSecurityNumber_LastFourNumbers[0]": data.dig('veteran', 'ssn')[5..8],
            # # Item 4
            # "#{page1_key}.DOBmonth[0]": data.dig('veteran', 'birthdate').split('-').second,
            # "#{page1_key}.DOBday[0]": data.dig('veteran', 'birthdate').split('-').last.first(2),
            # "#{page1_key}.DOByear[0]": data.dig('veteran', 'birthdate').split('-').first,
            # # Item 5
            # "#{page1_key}.VeteransServiceNumber[0]": data.dig('veteran', 'serviceNumber'),
            # # Item 6 Service Branch
            # "#{page1_key}.ARMYCheckbox1[0]": (data.dig('veteran', 'serviceBranch') == 'ARMY' ? 1 : 0),
            # "#{page1_key}.NAVYCheckbox2[0]": (data.dig('veteran', 'serviceBranch') == 'NAVY' ? 1 : 0),
            # "#{page1_key}.AIR_FORCECheckbox3[0]": (data.dig('veteran', 'serviceBranch') == 'AIR_FORCE' ? 1 : 0),
            # "#{page1_key}.MARINE_CORPSCheckbox4[0]": (data.dig('veteran', 'serviceBranch') == 'MARINE_CORPS' ? 1 : 0),
            # "#{page1_key}.COAST_GUARDCheckbox5[0]": (data.dig('veteran', 'serviceBranch') == 'COAST_GUARD' ? 1 : 0),
            # "#{page1_key}.SPACE_FORCECheckbox3[0]": (data.dig('veteran', 'serviceBranch') == 'SPACE_FORCE' ? 1 : 0),
            # "#{page1_key}.OTHER_Checkbox6[0]": (data.dig('veteran', 'serviceBranch') == 'OTHER' ? 1 : 0),
            # "#{page1_key}.JF15[0]": data.dig('veteran', 'serviceBranchOther'),
            # # Item 7
            # "#{page1_key}.Veterans_MailingAddress_NumberAndStreet[0]": data.dig('veteran', 'address', 'addressLine1'),
            # "#{page1_key}.MailingAddress_ApartmentOrUnitNumber[1]": data.dig('veteran', 'address', 'addressLine2'),
            # "#{page1_key}.MailingAddress_City[1]": data.dig('veteran', 'address', 'city'),
            # "#{page1_key}.MailingAddress_StateOrProvince[1]": data.dig('veteran', 'address', 'stateCode'),
            # "#{page1_key}.MailingAddress_Country[1]": data.dig('veteran', 'address', 'country'),
            # "#{page1_key}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": data.dig('veteran', 'address', 'zipCode'),
            # "#{page1_key}.MailingAddress_ZIPOrPostalCode_ZIPOrPostalCode_LastFourNumbers[1]": data.dig('veteran', 'address', 'zipCodeSuffix'),
            # # Item 8
            # "#{page1_key}.TelephoneNumber_IncludeAreaCode[0]": "#{data.dig('veteran', 'phone', 'areaCode')} #{data.dig('veteran', 'phone', 'phoneNumber')}",
            # # Item 9
            # "#{page1_key}.EmailAddress_Optional[0]": data.dig('veteran', 'email'),

            # # Section II
            # # Item 10
            # "#{page1_key}.Claimants_First_Name[0]": data.dig('claimant', 'firstName'),
            # "#{page1_key}.Claimants_Middle_Initial1[0]": data.dig('claimant', 'middleInitial'),
            # "#{page1_key}.Claimants_Last_Name[0]": data.dig('claimant', 'lastName'),
            # # Item 11
            # "#{page1_key}.MailingAddress_NumberAndStreet[0]": data.dig('claimant', 'address', 'addressLine1'),
            # "#{page1_key}.MailingAddress_ApartmentOrUnitNumber[0]": data.dig('claimant', 'address', 'addressLine2'),
            # "#{page1_key}.MailingAddress_City[0]": data.dig('claimant', 'address', 'city'),
            # "#{page1_key}.MailingAddress_StateOrProvince[0]": data.dig('claimant', 'address', 'stateCode'),
            # "#{page1_key}.MailingAddress_Country[0]": data.dig('claimant', 'address', 'country'),
            # "#{page1_key}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": data.dig('claimant', 'address', 'zipCode'),
            # "#{page1_key}.CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": data.dig('address', 'zipCodeSuffix'),
            # # Item 12
            # "#{page1_key}.TelephoneNumber_IncludeAreaCode[1]": "#{data.dig('claimant', 'phone', 'areaCode')} #{data.dig('claimant', 'phone', 'phoneNumber')}",
            # # Item 13
            # "#{page1_key}.EmailAddress_Optional[1]": data.dig('claimant', 'email'),
            # # Item 14
            # "#{page1_key}.RelationshipToVeteran[0]": data.dig('claimant', 'relationship'),

            # # Section III
            # # Item 15A
            # "#{page1_key}.NAME_OF_INDIVIDUAL_APPOINTED_AS_REPRESENTATIVE[0]": "#{data.dig('representative', 'firstName')} #{data.dig('representative', 'lastName')}",
            # # Item 15B
            # "#{page1_key}.Checkbox1[0]": (data.dig('representative', 'type') == 'ATTORNEY' ? 1 : 0),
            # "#{page1_key}.Checkbox2[0]": (data.dig('representative', 'type') == 'AGENT' ? 1 : 0),
            # # Item 18
            # "#{page1_key}.ADDRESSOFINDIVIDUALAPPOINTEDASCLAIMANTSREPRESENTATATIVE[0]": stringify_address(data.dig('representative', 'address'))
          }
        end
        # rubocop:enable Layout/LineLength
      end
    end
  end
end
