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
        # Set the template path that will be used by the base class.
        #
        # @param data [Hash] Hash of data to add to the pdf
        def set_template_path
          @template_path = template_path
        end

        # rubocop:disable Layout/LineLength
        # rubocop:disable Metrics/MethodLength
        def template_options(data)
          p "data: #{data}", "data.veteran_date_of_birth: #{data.veteran_date_of_birth}",
            "data.veteran_date_of_birth.split('/'): #{data.veteran_date_of_birth.split('/')}"
          page1_key = 'form1[0].#subform[0]'
          page2_key = 'form1[0].#subform[1]'
          {
            # Page 1
            # Section I
            # Veteran Name
            "#{page1_key}.VeteransLastName[0]": data.veteran_last_name,
            "#{page1_key}.VeteransMiddleInitial1[0]": data.veteran_middle_initial,
            "#{page1_key}.VeteransFirstName[0]": data.veteran_first_name,
            # Veteran SSN
            "#{page1_key}.SocialSecurityNumber_FirstThreeNumbers[0]": data.veteran_social_security_number[0..2],
            "#{page1_key}.SocialSecurityNumber_SecondTwoNumbers[0]": data.veteran_social_security_number[3..4],
            "#{page1_key}.SocialSecurityNumber_LastFourNumbers[0]": data.veteran_social_security_number[5..8],
            # Veteran File Number
            "#{page1_key}.VAFileNumber[0]": data.veteran_va_file_number,
            # Veteran DOB
            "#{page1_key}.DOBmonth[0]": data.veteran_date_of_birth.split('/').first,
            "#{page1_key}.DOBday[0]": data.veteran_date_of_birth.split('/').second,
            "#{page1_key}.DOByear[0]": data.veteran_date_of_birth.split('/').last,
            # Veteran Service Number
            "#{page1_key}.VeteransServiceNumber_If_Applicable[0]": data.veteran_service_number,
            # Veteran Insurance Number
            "#{page1_key}.InsuranceNumber_s[0]": data.veteran_insurance_numbers.join(', '),
            # Veteran Address
            "#{page1_key}.Claimants_MailingAddress_NumberAndStreet[1]": data.veteran_address_line1,
            "#{page1_key}.Claimants_MailingAddress_ApartmentOrUnitNumber[1]": data.veteran_address_line2,
            "#{page1_key}.Claimants_MailingAddress_City[1]": data.veteran_city,
            "#{page1_key}.Claimants_MailingAddress_StateOrProvince[1]": data.veteran_state_code,
            "#{page1_key}.Claimants_MailingAddress_Country[1]": data.veteran_country,
            "#{page1_key}.Claimants_MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": data.veteran_zip_code,
            "#{page1_key}.Claimants_MailingAddress_ZIPOrPostalCode_LastFourNumbers[1]": data.veteran_zip_code_suffix,
            # Veteran Phone Number
            "#{page1_key}.TelephoneNumber_IncludeAreaCode[1]": data.veteran_phone,
            # # Veteran Email
            "#{page1_key}.EmailAddress_Optional[0]": data.veteran_email,

            # # Section II
            # # Claimant Name
            "#{page1_key}.Claimants_FirstName[0]": data.claimant_first_name,
            "#{page1_key}.Claimants_MiddleInitial1[0]": data.claimant_middle_initial,
            "#{page1_key}.Claimants_LastName[0]": data.claimant_last_name,
            # Claimant DOB
            "#{page1_key}.DOBmonth[1]": data.claimant_date_of_birth.split('/').first,
            "#{page1_key}.DOBday[1]": data.claimant_date_of_birth.split('/').second,
            "#{page1_key}.DOByear[1]": data.claimant_date_of_birth.split('/').last,
            # Claimant Relationship
            "#{page1_key}.Relationship_To_Veteran[0]": data.claimant_relationship,
            # Claimant Address
            "#{page1_key}.Claimants_MailingAddress_NumberAndStreet[0]": data.claimant_address_line1,
            "#{page1_key}.Claimants_MailingAddress_ApartmentOrUnitNumber[0]": data.claimant_address_line2,
            "#{page1_key}.Claimants_MailingAddress_City[0]": data.claimant_city,
            "#{page1_key}.Claimants_MailingAddress_StateOrProvince[0]": data.claimant_state_code,
            "#{page1_key}.Claimants_MailingAddress_Country[0]": data.claimant_country,
            "#{page1_key}.Claimants_MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": data.claimant_zip_code,
            "#{page1_key}.Claimants_MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": data.claimant_zip_code_suffix,
            # Claimant Phone Number
            "#{page1_key}.TelephoneNumber_IncludeAreaCode[0]": data.claimant_phone,
            # Claimant Email
            "#{page1_key}.Claimants_EmailAddress_Optional[0]": data.claimant_email,

            # Section III
            # Service Organization Name
            "#{page1_key}.Name_Of_Service_Organization[0]": data.organization_name,

            # Page 2
            # Header
            "#{page2_key}.SocialSecurityNumber_FirstThreeNumbers[1]": data.veteran_social_security_number[0..2],
            "#{page2_key}.SocialSecurityNumber_SecondTwoNumbers[1]": data.veteran_social_security_number[3..4],
            "#{page2_key}.SocialSecurityNumber_LastFourNumbers[1]": data.veteran_social_security_number[5..8],
            # # Section IV
            # Record Consent
            "#{page2_key}.I_Authorize[1]": data.record_consent == true ? 1 : 0,
            # # Item 20
            "#{page2_key}.Drug_Abuse[0]": data.consent_limits.present? && data.consent_limits.include?('DRUG_ABUSE') ? 1 : 0,
            "#{page2_key}.Alcoholism_Or_Alcohol_Abuse[0]": data.consent_limits.present? && data.consent_limits.include?('ALCOHOLISM') ? 1 : 0,
            "#{page2_key}.Infection_With_The_Human_Immunodeficiency_Virus_HIV[0]": data.consent_limits.present? && data.consent_limits.include?('HIV') ? 1 : 0,
            "#{page2_key}.sicklecellanemia[0]": data.consent_limits.present? && data.consent_limits.include?('SICKLE_CELL') ? 1 : 0,
            # Consent Address Change
            "#{page2_key}.I_Authorize[0]": data.consent_address_change == true ? 1 : 0
          }
        end
        # rubocop:enable Layout/LineLength
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
