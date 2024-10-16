# frozen_string_literal: true

module RepresentationManagement
  module V0
    module PdfConstructor
      class Form2122 < RepresentationManagement::V0::PdfConstructor::Base
        PAGE1_KEY = 'form1[0].#subform[0]'
        PAGE2_KEY = 'form1[0].#subform[1]'

        protected

        def next_steps_page?
          false
        end

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

        def template_options(data)
          {
            # Service Organization Name
            "#{PAGE1_KEY}.Name_Of_Service_Organization[0]": data.organization_name
          }.merge(veteran_identification(data))
            .merge(veteran_contact_details(data))
            .merge(claimant_identification(data))
            .merge(claimant_contact_details(data))
            .merge(page2_options(data))
        end

        def veteran_identification(data)
          {
            # Veteran Name
            "#{PAGE1_KEY}.VeteransLastName[0]": data.veteran_last_name,
            "#{PAGE1_KEY}.VeteransMiddleInitial1[0]": data.veteran_middle_initial,
            "#{PAGE1_KEY}.VeteransFirstName[0]": data.veteran_first_name,
            # Veteran SSN
            "#{PAGE1_KEY}.SocialSecurityNumber_FirstThreeNumbers[0]": \
            data.veteran_social_security_number[0..2],
            "#{PAGE1_KEY}.SocialSecurityNumber_SecondTwoNumbers[0]": \
            data.veteran_social_security_number[3..4],
            "#{PAGE1_KEY}.SocialSecurityNumber_LastFourNumbers[0]": \
            data.veteran_social_security_number[5..8],
            # Veteran File Number
            "#{PAGE1_KEY}.VAFileNumber[0]": data.veteran_va_file_number,
            # Veteran DOB
            "#{PAGE1_KEY}.DOBmonth[0]": data.veteran_date_of_birth.split('/').first,
            "#{PAGE1_KEY}.DOBday[0]": data.veteran_date_of_birth.split('/').second,
            "#{PAGE1_KEY}.DOByear[0]": data.veteran_date_of_birth.split('/').last,
            # Veteran Service Number
            "#{PAGE1_KEY}.VeteransServiceNumber_If_Applicable[0]": \
            data.veteran_service_number,
            # Veteran Insurance Number
            "#{PAGE1_KEY}.InsuranceNumber_s[0]": data.veteran_insurance_numbers.join(', ')
          }
        end

        def veteran_contact_details(data)
          {
            # Veteran Address
            "#{PAGE1_KEY}.Claimants_MailingAddress_NumberAndStreet[1]": \
            data.veteran_address_line1,
            "#{PAGE1_KEY}.Claimants_MailingAddress_ApartmentOrUnitNumber[1]": \
            data.veteran_address_line2,
            "#{PAGE1_KEY}.Claimants_MailingAddress_City[1]": data.veteran_city,
            "#{PAGE1_KEY}.Claimants_MailingAddress_StateOrProvince[1]": \
            data.veteran_state_code,
            "#{PAGE1_KEY}.Claimants_MailingAddress_Country[1]": data.veteran_country,
            "#{PAGE1_KEY}.Claimants_MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": \
            data.veteran_zip_code,
            "#{PAGE1_KEY}.Claimants_MailingAddress_ZIPOrPostalCode_LastFourNumbers[1]": \
            data.veteran_zip_code_suffix,
            # Veteran Phone Number
            "#{PAGE1_KEY}.TelephoneNumber_IncludeAreaCode[1]": data.veteran_phone,
            # Veteran Email
            "#{PAGE1_KEY}.EmailAddress_Optional[0]": data.veteran_email
          }
        end

        def claimant_identification(data)
          return {} if data.claimant_last_name.blank?

          {
            # Claimant Name
            "#{PAGE1_KEY}.Claimants_FirstName[0]": data.claimant_first_name,
            "#{PAGE1_KEY}.Claimants_MiddleInitial1[0]": data.claimant_middle_initial,
            "#{PAGE1_KEY}.Claimants_LastName[0]": data.claimant_last_name,
            # Claimant DOB
            "#{PAGE1_KEY}.DOBmonth[1]": data.claimant_date_of_birth.split('/').first,
            "#{PAGE1_KEY}.DOBday[1]": data.claimant_date_of_birth.split('/').second,
            "#{PAGE1_KEY}.DOByear[1]": data.claimant_date_of_birth.split('/').last,
            # Claimant Relationship
            "#{PAGE1_KEY}.Relationship_To_Veteran[0]": data.claimant_relationship
          }
        end

        def claimant_contact_details(data)
          return {} if data.claimant_last_name.blank?

          {
            # Claimant Address
            "#{PAGE1_KEY}.Claimants_MailingAddress_NumberAndStreet[0]": \
            data.claimant_address_line1,
            "#{PAGE1_KEY}.Claimants_MailingAddress_ApartmentOrUnitNumber[0]": \
            data.claimant_address_line2,
            "#{PAGE1_KEY}.Claimants_MailingAddress_City[0]": data.claimant_city,
            "#{PAGE1_KEY}.Claimants_MailingAddress_StateOrProvince[0]": \
            data.claimant_state_code,
            "#{PAGE1_KEY}.Claimants_MailingAddress_Country[0]": data.claimant_country,
            "#{PAGE1_KEY}.Claimants_MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": \
            data.claimant_zip_code,
            "#{PAGE1_KEY}.Claimants_MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": \
            data.claimant_zip_code_suffix,
            # Claimant Phone Number
            "#{PAGE1_KEY}.TelephoneNumber_IncludeAreaCode[0]": data.claimant_phone,
            # Claimant Email
            "#{PAGE1_KEY}.Claimants_EmailAddress_Optional[0]": data.claimant_email
          }
        end

        def page2_options(data)
          {
            # Header
            "#{PAGE2_KEY}.SocialSecurityNumber_FirstThreeNumbers[1]": \
            data.veteran_social_security_number[0..2],
            "#{PAGE2_KEY}.SocialSecurityNumber_SecondTwoNumbers[1]": \
            data.veteran_social_security_number[3..4],
            "#{PAGE2_KEY}.SocialSecurityNumber_LastFourNumbers[1]": \
            data.veteran_social_security_number[5..8],
            # Record Consent
            "#{PAGE2_KEY}.I_Authorize[1]": data.record_consent == true ? 1 : 0,
            # Item 20
            "#{PAGE2_KEY}.Drug_Abuse[0]": \
            data.consent_limits.present? && data.consent_limits.include?('DRUG_ABUSE') ? 1 : 0,
            "#{PAGE2_KEY}.Alcoholism_Or_Alcohol_Abuse[0]": \
            data.consent_limits.present? && data.consent_limits.include?('ALCOHOLISM') ? 1 : 0,
            "#{PAGE2_KEY}.Infection_With_The_Human_Immunodeficiency_Virus_HIV[0]": \
            data.consent_limits.present? && data.consent_limits.include?('HIV') ? 1 : 0,
            "#{PAGE2_KEY}.sicklecellanemia[0]": \
            data.consent_limits.present? && data.consent_limits.include?('SICKLE_CELL') ? 1 : 0,
            # Consent Address Change
            "#{PAGE2_KEY}.I_Authorize[0]": data.consent_address_change == true ? 1 : 0
          }
        end
      end
    end
  end
end
