# frozen_string_literal: true

module RepresentationManagement
  module V0
    module PdfConstructor
      class Form2122 < RepresentationManagement::V0::PdfConstructor::Base
        protected

        def template_path
          Rails.root.join('modules',
                          'representation_management',
                          'lib',
                          'representation_management',
                          'v0',
                          'pdf_constructor',
                          'pdf_templates',
                          '21-22.pdf')
        end

        #
        # Add text signature to pdf page .
        #
        # @param data [Hash] Hash of data to add to the pdf
        def set_template_path
          @template_path = template_path
        end

        # rubocop:disable Layout/LineLength
        def page2_options(data)
          # base_form = 'F[0].Page_2[0]'
          {
            # Header
            # "#{base_form}.SocialSecurityNumber_FirstThreeNumbers[0]": data.dig('veteran', 'ssn')[0..2],
            # "#{base_form}.SocialSecurityNumber_SecondTwoNumbers[0]": data.dig('veteran', 'ssn')[3..4],
            # "#{base_form}.SocialSecurityNumber_LastFourNumbers[0]": data.dig('veteran', 'ssn')[5..8],
            # # Section IV
            # # Item 19
            # "#{base_form}.I_Authorize[1]": data['recordConsent'] == true ? 1 : 0,
            # # Item 20
            # "#{base_form}.Drug_Abuse[0]": data['consentLimits'].present? && data['consentLimits'].include?('DRUG_ABUSE') ? 1 : 0,
            # "#{base_form}.Alcoholism_Or_Alcohol_Abuse[0]": data['consentLimits'].present? && data['consentLimits'].include?('ALCOHOLISM') ? 1 : 0,
            # "#{base_form}.Infection_With_The_Human_Immunodeficiency_Virus_HIV[0]": data['consentLimits'].present? && data['consentLimits'].include?('HIV') ? 1 : 0,
            # "#{base_form}.sicklecellanemia[0]": data['consentLimits'].present? && data['consentLimits'].include?('SICKLE_CELL') ? 1 : 0,
            # # Item 21
            # "#{base_form}.I_Authorize[0]": data['consentAddressChange'] == true ? 1 : 0,
            # # Item 22B
            # "#{base_form}.Date_Signed[0]": I18n.l(Time.zone.now.to_date, format: :va_form),
            # # Item 23B
            # "#{base_form}.Date_Signed[1]": I18n.l(Time.zone.now.to_date, format: :va_form)
          }
        end

        def template_options(data)
          p "data: #{data}", "data.veteran_date_of_birth: #{data.veteran_date_of_birth}", "data.veteran_date_of_birth.split('/'): #{data.veteran_date_of_birth.split('/')}"
          base_form = 'form1[0].#subform[0]'
          {
            # Section I
            # Veteran Name
            "#{base_form}.VeteransLastName[0]": data.veteran_last_name,
            "#{base_form}.VeteransMiddleInitial1[0]": data.veteran_middle_initial,
            "#{base_form}.VeteransFirstName[0]": data.veteran_first_name,
            # Veteran SSN
            "#{base_form}.SocialSecurityNumber_FirstThreeNumbers[0]": data.veteran_social_security_number[0..2],
            "#{base_form}.SocialSecurityNumber_SecondTwoNumbers[0]": data.veteran_social_security_number[3..4],
            "#{base_form}.SocialSecurityNumber_LastFourNumbers[0]": data.veteran_social_security_number[5..8],
            # Veteran File Number
            "#{base_form}.VAFileNumber[0]": data.veteran_va_file_number,
            # Veteran DOB
            "#{base_form}.DOBmonth[0]": data.veteran_date_of_birth.split('/').first,
            "#{base_form}.DOBday[0]": data.veteran_date_of_birth.split('/').second,
            "#{base_form}.DOByear[0]": data.veteran_date_of_birth.split('/').last,
            # Veteran Service Number
            "#{base_form}.VeteransServiceNumber_If_Applicable[0]": data.veteran_service_number,
            # Veteran Insurance Number
            "#{base_form}.InsuranceNumber_s[0]": data.veteran_insurance_numbers,
            # Veteran Address
            "#{base_form}.Claimants_MailingAddress_NumberAndStreet[1]": data.veteran_address_line1,
            "#{base_form}.Claimants_MailingAddress_ApartmentOrUnitNumber[1]": data.veteran_address_line2,
            "#{base_form}.Claimants_MailingAddress_City[1]": data.veteran_city,
            "#{base_form}.Claimants_MailingAddress_StateOrProvince[1]": data.veteran_state_code,
            "#{base_form}.Claimants_MailingAddress_Country[1]": data.veteran_country,
            "#{base_form}.Claimants_MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": data.veteran_zip_code,
            "#{base_form}.Claimants_MailingAddress_ZIPOrPostalCode_LastFourNumbers[1]": data.veteran_zip_code_suffix,
            # Veteran Phone Number
            "#{base_form}.TelephoneNumber_IncludeAreaCode[1]": data.veteran_phone,
            # # Veteran Email
            "#{base_form}.EmailAddress_Optional[0]": data.veteran_email

            # # Section II
            # # Item 10
            # "#{base_form}.Claimants_FirstName[0]": data.dig('claimant', 'firstName'),
            # "#{base_form}.Claimants_MiddleInitial1[0]": data.dig('claimant', 'middleInitial'),
            # "#{base_form}.Claimants_LastName[0]": data.dig('claimant', 'lastName'),
            # # Item 11
            # "#{base_form}.Claimants_MailingAddress_NumberAndStreet[0]": data.dig('claimant', 'address', 'addressLine1'),
            # "#{base_form}.Claimants_MailingAddress_ApartmentOrUnitNumber[0]": data.dig('claimant', 'address', 'addressLine2'),
            # "#{base_form}.Claimants_MailingAddress_City[0]": data.dig('claimant', 'address', 'city'),
            # "#{base_form}.Claimants_MailingAddress_StateOrProvince[0]": data.dig('claimant', 'address', 'stateCode'),
            # "#{base_form}.Claimants_MailingAddress_Country[0]": data.dig('claimant', 'address', 'country'),
            # "#{base_form}.Claimants_MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": data.dig('claimant', 'address', 'zipCode'),
            # "#{base_form}.Claimants_MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": data.dig('address', 'zipCodeSuffix'),
            # # Item 12
            # "#{base_form}.TelephoneNumber_IncludeAreaCode[0]": "#{data.dig('claimant', 'phone', 'areaCode')} #{data.dig('claimant', 'phone', 'phoneNumber')}",
            # # Item 13
            # "#{base_form}.Claimants_EmailAddress_Optional[0]": data.dig('claimant', 'email'),
            # # Item 14
            # "#{base_form}.Relationship_To_Veteran[0]": data.dig('claimant', 'relationship'),

            # # Section III
            # # Item 15
            # "#{base_form}.Name_Of_Service_Organization[0]": data.dig('serviceOrganization', 'organizationName'),
            # # Item 16A
            # "#{base_form}.Name_Of_Official_Representative[0]": "#{data.dig('serviceOrganization', 'firstName')} #{data.dig('serviceOrganization', 'lastName')}",
            # # Item 16B
            # "#{base_form}.Job_Title_Of_Person_Named_In_Item15A[0]": data.dig('serviceOrganization', 'jobTitle'),
            # # Item 17
            # "#{base_form}.Email_Address[0]": data.dig('serviceOrganization', 'email'),
            # # Item 18
            # "#{base_form}.Date_Of_This_Appointment[0]": I18n.l(Time.zone.now.to_date, format: :va_form)
          }
        end
        # rubocop:enable Layout/LineLength
      end
    end
  end
end
