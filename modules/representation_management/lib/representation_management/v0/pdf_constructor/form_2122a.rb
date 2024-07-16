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
                          'v0',
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
            # Veteran Name
            "#{page1_key}.Veterans_Last_Name[0]": data.veteran_last_name,
            "#{page1_key}.Veterans_Middle_Initial[0]": data.veteran_middle_initial,
            "#{page1_key}.Veterans_First_Name[0]": data.veteran_first_name,
            # Veteran SSN
            "#{page1_key}.SocialSecurityNumber_FirstThreeNumbers[0]": data.veteran_social_security_number[0..2],
            "#{page1_key}.SocialSecurityNumber_SecondTwoNumbers[0]": data.veteran_social_security_number[3..4],
            "#{page1_key}.SocialSecurityNumber_LastFourNumbers[0]": data.veteran_social_security_number[5..8],
            # Veteran File Number
            "#{page1_key}.Veterans_Service_Number_If_Applicable[0]": data.veteran_va_file_number,
            # Veteran DOB
            "#{page1_key}.Date_Of_Birth_Month[0]": data.veteran_date_of_birth.split('/').first,
            "#{page1_key}.Date_Of_Birth_Day[0]": data.veteran_date_of_birth.split('/').second,
            "#{page1_key}.Date_Of_Birth_Year[0]": data.veteran_date_of_birth.split('/').last,
            # Veteran Service Number
            "#{page1_key}.Veterans_Service_Number_If_Applicable[1]": data.veteran_service_number,
            # Item 6 Service Branch
            "#{page1_key}.RadioButtonList[1]": service_branch_checkbox(data.veteran_service_branch),
            # Veteran Mailing Address
            "#{page1_key}.MailingAddress_NumberAndStreet[0]": data.veteran_address_line1,
            "#{page1_key}.MailingAddress_ApartmentOrUnitNumber[0]": data.veteran_address_line2,
            "#{page1_key}.MailingAddress_City[0]": data.veteran_city,
            "#{page1_key}.MailingAddress_StateOrProvince[0]": data.veteran_state_code,
            "#{page1_key}.MailingAddress_Country[0]": data.veteran_country,
            "#{page1_key}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": data.veteran_zip_code,
            "#{page1_key}.MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": data.veteran_zip_code_suffix,
            # Veteran Phone Number
            "#{page1_key}.Telephone_Number_Area_Code[1]": data.veteran_phone[0..2],
            "#{page1_key}.Telephone_Middle_Three_Numbers[0]": data.veteran_phone[3..5],
            "#{page1_key}.Telephone_Last_Four_Numbers[1]": data.veteran_phone[6..9],
            # Veteran Email
            "#{page1_key}.E_Mail_Address_Optional[1]": data.veteran_email,

            # # Section II
            # Claimant Name
            "#{page1_key}.Claimants_First_Name[0]": data.claimant_first_name,
            "#{page1_key}.Claimants_Middle_Initial[0]": data.claimant_middle_initial,
            "#{page1_key}.Claimants_Last_Name[0]": data.claimant_last_name,
            # Claimant DOB
            "#{page1_key}.Claimants_Date_Of_Birth_Month[0]": data.claimant_date_of_birth.split('/').first,
            "#{page1_key}.Date_Of_Birth_Day[1]": data.claimant_date_of_birth.split('/').second,
            "#{page1_key}.Date_Of_Birth_Year[1]": data.claimant_date_of_birth.split('/').last,
            # Claimant Relationship
            "#{page1_key}.RelationshipToVeteran[0]": data.claimant_relationship,
            # Claimant Mailing Address
            "#{page1_key}.MailingAddress_NumberAndStreet[1]": data.claimant_address_line1,
            "#{page1_key}.MailingAddress_ApartmentOrUnitNumber[1]": data.claimant_address_line2,
            "#{page1_key}.MailingAddress_City[1]": data.claimant_city,
            "#{page1_key}.MailingAddress_StateOrProvince[1]": data.claimant_state_code,
            "#{page1_key}.MailingAddress_Country[1]": data.claimant_country,
            "#{page1_key}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": data.claimant_zip_code,
            "#{page1_key}.MailingAddress_ZIPOrPostalCode_LastFourNumbers[1]": data.claimant_zip_code_suffix,
            # Claimant Phone Number
            "#{page1_key}.Telephone_Number_Area_Code[0]": data.claimant_phone[0..2],
            "#{page1_key}.Telphone_Middle_Three_Numbers[0]": data.claimant_phone[3..5],
            "#{page1_key}.Telephone_Last_Four_Numbers[0]": data.claimant_phone[6..9],
            # Claimant Email
            "#{page1_key}.E_Mail_Address_Optional[0]": data.claimant_email,

            # # Section III
            # Representative Name
            "#{page1_key}.Name_Of_Individual_Appointed_As_Representative_First_Name[0]": data.representative_first_name,
            "#{page1_key}.Middle_Initial[0]": data.representative_middle_initial,
            "#{page1_key}.Last_Name[0]": data.representative_last_name,
            # Representative Type
            "#{page1_key}.RadioButtonList[0]": representative_type_checkbox(data.representative_type)
            # # Item 18
            # "#{page1_key}.ADDRESSOFINDIVIDUALAPPOINTEDASCLAIMANTSREPRESENTATATIVE[0]": stringify_address(data.dig('representative', 'address'))
          }
        end

        # rubocop:enable Layout/LineLength
        def service_branch_checkbox(service_branch)
          service_branch_map = {
            'ARMY' => 4,
            'NAVY' => 5,
            'AIR_FORCE' => 6,
            'MARINE_CORPS' => 7,
            'COAST_GUARD' => 8,
            'SPACE_FORCE' => 9,
            'NOAA' => 10,
            'USPHS' => 11
          }
          service_branch_map[service_branch]
        end

        def representative_type_checkbox(representative_type)
          representative_type_map = {
            'ATTORNEY' => 4,
            'AGENT' => 1,
            'INDIVIDUAL' => 3,
            'VSO' => 2
          }
          representative_type_map[representative_type]
        end
      end
    end
  end
end
