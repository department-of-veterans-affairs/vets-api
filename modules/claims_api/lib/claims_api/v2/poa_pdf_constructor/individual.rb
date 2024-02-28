# frozen_string_literal: true

require 'claims_api/v2/poa_pdf_constructor/base'

module ClaimsApi
  module V2
    module PoaPdfConstructor
      class Individual < ClaimsApi::V2::PoaPdfConstructor::Base
        protected

        def page1_template_path
          Rails.root.join('modules', 'claims_api', 'config', 'pdf_templates', '21-22A', '1.pdf')
        end

        def page2_template_path
          Rails.root.join('modules', 'claims_api', 'config', 'pdf_templates', '21-22A', '2.pdf')
        end

        def page3_template_path
          Rails.root.join('modules', 'claims_api', 'config', 'pdf_templates', '21-22A', '3.pdf')
        end

        def page4_template_path
          nil
        end

        #
        # Add text signature to pdf page .
        #
        # @param data [Hash] Hash of data to add to the pdf
        def sign_pdf_text(data)
          @page1_path = if data.dig('representative',
                                    'type') == 'INDIVIDUAL PROVIDING REPRESENTATION UNDER SECTION 14.630'
                          insert_text_signatures(page1_template_path, data['text_signatures']['page1'])
                        else
                          page1_template_path
                        end
          @page2_path = insert_text_signatures(page2_template_path, data['text_signatures']['page2'])
          @page3_path = page3_template_path
          @page4_path = page4_template_path
        end

        def page2_options(data)
          base_form = 'form1[0].#subform[1]'
          {
            # Header
            "#{base_form}.SocialSecurityNumber_FirstThreeNumbers[1]": data.dig('veteran', 'ssn')[0..2],
            "#{base_form}.SocialSecurityNumber_SecondTwoNumbers[1]": data.dig('veteran', 'ssn')[3..4],
            "#{base_form}.SocialSecurityNumber_LastFourNumbers[1]": data.dig('veteran', 'ssn')[5..8],
            # Section IV
            # Item 19
            "#{base_form}.AuthorizationForRepAccessToRecords[0]": data['recordConsent'] == true ? 1 : 0,
            # Item 20
            "#{base_form}.LIMITATIONOFCONSENT[0]": data['consentLimits']&.join(', '),
            # Item 21
            "#{base_form}.AuthorizationForRepActClaimantsBehalf[0]": data['consentAddressChange'] == true ? 1 : 0,
            # Conditions of Appointment
            # Item 22B
            "#{base_form}.Date_Signed[0]": I18n.l(Time.zone.now.to_date, format: :va_form),
            # Item 23
            "#{base_form}.LIMITATIONS[0]": data['conditionsOfAppointment']&.join(', '),
            # Item 24B
            "#{base_form}.Date_Signed[1]": I18n.l(Time.zone.now.to_date, format: :va_form)
          }
        end

        # rubocop:disable Metrics/MethodLength
        # rubocop:disable Layout/LineLength
        def page1_options(data)
          base_form = 'form1[0].#subform[0]'
          {
            # Section !
            # Item 1
            "#{base_form}.VeteransLastName[0]": data.dig('veteran', 'lastName'),
            "#{base_form}.VeteransFirstName[0]": data.dig('veteran', 'firstName'),
            # Item 2
            "#{base_form}.SocialSecurityNumber_FirstThreeNumbers[0]": data.dig('veteran', 'ssn')[0..2],
            "#{base_form}.SocialSecurityNumber_SecondTwoNumbers[0]": data.dig('veteran', 'ssn')[3..4],
            "#{base_form}.SocialSecurityNumber_LastFourNumbers[0]": data.dig('veteran', 'ssn')[5..8],
            # Item 3
            "#{base_form}.VAFileNumber[0]": data.dig('veteran', 'vaFileNumber'),
            # Item 4
            "#{base_form}.DOBmonth[0]": data.dig('veteran', 'birthdate').split('-').second,
            "#{base_form}.DOBday[0]": data.dig('veteran', 'birthdate').split('-').last.first(2),
            "#{base_form}.DOByear[0]": data.dig('veteran', 'birthdate').split('-').first,
            # Item 5
            "#{base_form}.VeteransServiceNumber[0]": data.dig('veteran', 'serviceNumber'),
            # Item 6
            "#{base_form}.ARMYCheckbox1[0]": (data.dig('veteran', 'serviceBranch') == 'ARMY' ? 1 : 0),
            "#{base_form}.NAVYCheckbox2[0]": (data.dig('veteran', 'serviceBranch') == 'NAVY' ? 1 : 0),
            "#{base_form}.AIR_FORCECheckbox3[0]": (data.dig('veteran', 'serviceBranch') == 'AIR FORCE' ? 1 : 0),
            "#{base_form}.MARINE_CORPSCheckbox4[0]": (data.dig('veteran', 'serviceBranch') == 'MARINE CORPS' ? 1 : 0),
            "#{base_form}.COAST_GUARDCheckbox5[0]": (data.dig('veteran', 'serviceBranch') == 'COAST GUARD' ? 1 : 0),
            "#{base_form}.SPACE_FORCECheckbox3[0]": (data.dig('veteran', 'serviceBranch') == 'SPACE FORCE' ? 1 : 0),
            "#{base_form}.OTHER_Checkbox6[0]": (data.dig('veteran', 'serviceBranch') == 'OTHER' ? 1 : 0),
            # Item 7
            "#{base_form}.Veterans_MailingAddress_NumberAndStreet[0]": data.dig('veteran', 'address', 'numberAndStreet'),
            "#{base_form}.MailingAddress_ApartmentOrUnitNumber[1]": data.dig('veteran', 'address', 'aptUnitNumber'),
            "#{base_form}.MailingAddress_City[1]": data.dig('veteran', 'address', 'city'),
            "#{base_form}.MailingAddress_StateOrProvince[1]": data.dig('veteran', 'address', 'state'),
            "#{base_form}.MailingAddress_Country[1]": data.dig('veteran', 'address', 'country'),
            "#{base_form}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": data.dig('veteran', 'address', 'zipFirstFive'),
            "#{base_form}.MailingAddress_ZIPOrPostalCode_ZIPOrPostalCode_LastFourNumbers[1]": data.dig('veteran', 'address', 'zipLastFour'),
            # Item 8
            "#{base_form}.TelephoneNumber_IncludeAreaCode[0]": "#{data.dig('veteran', 'phone', 'areaCode')} #{data.dig('veteran', 'phone', 'phoneNumber')}",
            # Item 9
            "#{base_form}.EmailAddress_Optional[0]": data.dig('veteran', 'email'),

            # Section II
            # Item 10
            "#{base_form}.Claimants_First_Name[0]": data.dig('claimant', 'firstName'),
            "#{base_form}.Claimants_Middle_Initial1[0]": data.dig('claimant', 'middleInitial'),
            "#{base_form}.Claimants_Last_Name[0]": data.dig('claimant', 'lastName'),
            # Item 11
            "#{base_form}.MailingAddress_NumberAndStreet[0]": data.dig('claimant', 'address', 'numberAndStreet'),
            "#{base_form}.MailingAddress_ApartmentOrUnitNumber[0]": data.dig('claimant', 'address', 'aptUnitNumber'),
            "#{base_form}.MailingAddress_City[0]": data.dig('claimant', 'address', 'city'),
            "#{base_form}.MailingAddress_StateOrProvince[0]": data.dig('claimant', 'address', 'state'),
            "#{base_form}.MailingAddress_Country[0]": data.dig('claimant', 'address', 'country'),
            "#{base_form}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": data.dig('claimant', 'address', 'zipFirstFive'),
            "#{base_form}.CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": data.dig('address', 'zipLastFour'),
            # Item 12
            "#{base_form}.TelephoneNumber_IncludeAreaCode[1]": "#{data.dig('claimant', 'phone', 'areaCode')} #{data.dig('claimant', 'phone', 'phoneNumber')}",
            # Item 13
            "#{base_form}.EmailAddress_Optional[1]": data.dig('claimant', 'email'),
            # Item 14
            "#{base_form}.RelationshipToVeteran[0]": data.dig('claimant', 'relationship'),

            # Section III
            # Item 15A
            "#{base_form}.NAME_OF_INDIVIDUAL_APPOINTED_AS_REPRESENTATIVE[0]": "#{data.dig('representative', 'firstName')} #{data.dig('representative', 'lastName')}",
            # Item 15B
            "#{base_form}.Checkbox1[0]": (data.dig('representative', 'type') == 'ATTORNEY' ? 1 : 0),
            "#{base_form}.Checkbox2[0]": (data.dig('representative', 'type') == 'AGENT' ? 1 : 0),
            "#{base_form}.Checkbox3[0]": (data.dig('representative', 'type') == 'SERVICE ORGANIZATION REPRESENTATIVE' ? 1 : 0),
            "#{base_form}.Checkbox[0]": (data.dig('representative', 'type') == 'INDIVIDUAL PROVIDING REPRESENTATION UNDER SECTION 14.630' ? 1 : 0),
            "#{base_form}.SpecifyOrganization[0]": data.dig('representative', 'organizationName'),
            # Item 16B
            "#{base_form}.Date_Of_Signature[0]": (data.dig('representative', 'type') == 'INDIVIDUAL PROVIDING REPRESENTATION UNDER SECTION 14.630' ? I18n.l(Time.zone.now.to_date, format: :va_form) : nil),
            # Item 17B
            "#{base_form}.Date_Of_Signature[1]": (data.dig('representative', 'type') == 'INDIVIDUAL PROVIDING REPRESENTATION UNDER SECTION 14.630' ? I18n.l(Time.zone.now.to_date, format: :va_form) : nil),
            # Item 18
            "#{base_form}.ADDRESSOFINDIVIDUALAPPOINTEDASCLAIMANTSREPRESENTATATIVE[0]": stringify_address(data.dig('representative', 'address'))
          }
        end
        # rubocop:enable Metrics/MethodLength
        # rubocop:enable Layout/LineLength
      end
    end
  end
end
