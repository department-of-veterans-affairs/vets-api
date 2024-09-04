# frozen_string_literal: true

module RepresentationManagement
  module V0
    module PdfConstructor
      class Form2122a < RepresentationManagement::V0::PdfConstructor::Base
        PAGE1_KEY = 'form1[0].#subform[0]'
        PAGE2_KEY = 'form1[0].#subform[1]'
        PAGE3_KEY = 'form1[0].#subform[2]'

        protected

        def next_steps_page?
          true
        end

        def next_steps_contact(pdf, data)
          rep_name = <<~HEREDOC.squish
            #{data.representative_first_name}
            #{data.representative_middle_initial}
            #{data.representative_last_name}
          HEREDOC
          pdf.font('bitter', style: :bold) do
            pdf.text(rep_name)
          end
          pdf.text(data.representative_address_line1)
          pdf.text(data.representative_address_line2)
          city_state_zip = <<~HEREDOC.squish
            #{data.representative_city},
            #{data.representative_state_code}
            #{data.representative_zip_code}
          HEREDOC
          pdf.text(city_state_zip)
          pdf.move_down(5)
          pdf.text(data.representative_phone)
          pdf.text(data.representative_email_address)
        end

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

        def template_options(data)
          veteran_identification(data)
            .merge(veteran_contact_details(data))
            .merge(claimant_identification(data))
            .merge(claimant_contact_details(data))
            .merge(representative_identification(data))
            .merge(representative_contact_details(data))
            .merge(appointment_options(data))
            .merge(header_options(data))
        end

        def veteran_identification(data)
          {
            # Veteran Name
            "#{PAGE1_KEY}.Veterans_Last_Name[0]": data.veteran_last_name,
            "#{PAGE1_KEY}.Veterans_Middle_Initial[0]": data.veteran_middle_initial,
            "#{PAGE1_KEY}.Veterans_First_Name[0]": data.veteran_first_name,
            # Veteran SSN
            "#{PAGE1_KEY}.SocialSecurityNumber_FirstThreeNumbers[0]": data.veteran_social_security_number[0..2],
            "#{PAGE1_KEY}.SocialSecurityNumber_SecondTwoNumbers[0]": data.veteran_social_security_number[3..4],
            "#{PAGE1_KEY}.SocialSecurityNumber_LastFourNumbers[0]": data.veteran_social_security_number[5..8],
            # Veteran File Number
            "#{PAGE1_KEY}.Veterans_Service_Number_If_Applicable[0]": data.veteran_va_file_number,
            # Veteran DOB
            "#{PAGE1_KEY}.Date_Of_Birth_Month[0]": data.veteran_date_of_birth.split('/').first,
            "#{PAGE1_KEY}.Date_Of_Birth_Day[0]": data.veteran_date_of_birth.split('/').second,
            "#{PAGE1_KEY}.Date_Of_Birth_Year[0]": data.veteran_date_of_birth.split('/').last,
            # Veteran Service Number
            "#{PAGE1_KEY}.Veterans_Service_Number_If_Applicable[1]": data.veteran_service_number,
            # Item 6 Service Branch
            "#{PAGE1_KEY}.RadioButtonList[1]": service_branch_checkbox(data.veteran_service_branch)
          }
        end

        def veteran_contact_details(data)
          {
            # Veteran Mailing Address
            "#{PAGE1_KEY}.MailingAddress_NumberAndStreet[0]": data.veteran_address_line1,
            "#{PAGE1_KEY}.MailingAddress_ApartmentOrUnitNumber[0]": data.veteran_address_line2,
            "#{PAGE1_KEY}.MailingAddress_City[0]": data.veteran_city,
            "#{PAGE1_KEY}.MailingAddress_StateOrProvince[0]": data.veteran_state_code,
            "#{PAGE1_KEY}.MailingAddress_Country[0]": data.veteran_country,
            "#{PAGE1_KEY}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": data.veteran_zip_code,
            "#{PAGE1_KEY}.MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": data.veteran_zip_code_suffix,
            # Veteran Phone Number
            "#{PAGE1_KEY}.Telephone_Number_Area_Code[1]": data.veteran_phone ? data.veteran_phone[0..2] : '',
            "#{PAGE1_KEY}.Telephone_Middle_Three_Numbers[0]": data.veteran_phone ? data.veteran_phone[3..5] : '',
            "#{PAGE1_KEY}.Telephone_Last_Four_Numbers[1]": data.veteran_phone ? data.veteran_phone[6..9] : '',
            # Veteran Email
            "#{PAGE1_KEY}.E_Mail_Address_Optional[1]": data.veteran_email
          }
        end

        def claimant_identification(data)
          return {} if data.claimant_last_name.blank?

          {
            # Claimant Name
            "#{PAGE1_KEY}.Claimants_First_Name[0]": data.claimant_first_name,
            "#{PAGE1_KEY}.Claimants_Middle_Initial[0]": data.claimant_middle_initial,
            "#{PAGE1_KEY}.Claimants_Last_Name[0]": data.claimant_last_name,
            # Claimant DOB
            "#{PAGE1_KEY}.Claimants_Date_Of_Birth_Month[0]": data.claimant_date_of_birth.split('/').first,
            "#{PAGE1_KEY}.Date_Of_Birth_Day[1]": data.claimant_date_of_birth.split('/').second,
            "#{PAGE1_KEY}.Date_Of_Birth_Year[1]": data.claimant_date_of_birth.split('/').last,
            # Claimant Relationship
            "#{PAGE1_KEY}.RelationshipToVeteran[0]": data.claimant_relationship
          }
        end

        def claimant_contact_details(data)
          return {} if data.claimant_last_name.blank?

          {
            # Claimant Mailing Address
            "#{PAGE1_KEY}.MailingAddress_NumberAndStreet[1]": data.claimant_address_line1,
            "#{PAGE1_KEY}.MailingAddress_ApartmentOrUnitNumber[1]": data.claimant_address_line2,
            "#{PAGE1_KEY}.MailingAddress_City[1]": data.claimant_city,
            "#{PAGE1_KEY}.MailingAddress_StateOrProvince[1]": data.claimant_state_code,
            "#{PAGE1_KEY}.MailingAddress_Country[1]": data.claimant_country,
            "#{PAGE1_KEY}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": data.claimant_zip_code,
            "#{PAGE1_KEY}.MailingAddress_ZIPOrPostalCode_LastFourNumbers[1]": data.claimant_zip_code_suffix,
            # Claimant Phone Number
            "#{PAGE1_KEY}.Telephone_Number_Area_Code[0]": data.claimant_phone[0..2],
            "#{PAGE1_KEY}.Telphone_Middle_Three_Numbers[0]": data.claimant_phone[3..5],
            "#{PAGE1_KEY}.Telephone_Last_Four_Numbers[0]": data.claimant_phone[6..9],
            # Claimant Email
            "#{PAGE1_KEY}.E_Mail_Address_Optional[0]": data.claimant_email
          }
        end

        def representative_identification(data)
          {
            # Representative Name
            "#{PAGE1_KEY}.Name_Of_Individual_Appointed_As_Representative_First_Name[0]": data.representative_first_name,
            "#{PAGE1_KEY}.Middle_Initial[0]": data.representative_middle_initial,
            "#{PAGE1_KEY}.Last_Name[0]": data.representative_last_name,
            # Representative Type
            "#{PAGE1_KEY}.RadioButtonList[0]": representative_type_checkbox(data.representative_type)
          }
        end

        def representative_contact_details(data)
          {
            # Representative Mailing Address
            "#{PAGE2_KEY}.MailingAddress_NumberAndStreet[2]": data.representative_address_line1,
            "#{PAGE2_KEY}.MailingAddress_ApartmentOrUnitNumber[2]": data.representative_address_line2,
            "#{PAGE2_KEY}.MailingAddress_City[2]": data.representative_city,
            "#{PAGE2_KEY}.MailingAddress_StateOrProvince[2]": data.representative_state_code,
            "#{PAGE2_KEY}.MailingAddress_Country[2]": data.representative_country,
            "#{PAGE2_KEY}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[2]": data.representative_zip_code,
            "#{PAGE2_KEY}.MailingAddress_ZIPOrPostalCode_LastFourNumbers[2]": data.representative_zip_code_suffix,
            # Representative Phone Number
            "#{PAGE2_KEY}.Telephone_Number_Area_Code[2]": data.representative_phone[0..2],
            "#{PAGE2_KEY}.Telephone_Middle_Three_Numbers[1]": data.representative_phone[3..5],
            "#{PAGE2_KEY}.Telephone_Last_Four_Numbers[2]": data.representative_phone[6..9],
            # Representative Email
            "#{PAGE2_KEY}.E_Mail_Address_Of_Individual_Appointed_As_Claimants_Representative_Optional[0]": \
            data.representative_email_address
          }
        end

        def appointment_options(data)
          {
            # Record Consent
            "#{PAGE2_KEY}.AuthorizationForRepAccessToRecords[0]": data.record_consent == true ? 1 : 0,
            # Consent Limits
            "#{PAGE2_KEY}.RelationshipToVeteran[1]": limitations_of_consent_text(data.consent_limits),
            # Consent Address Change
            "#{PAGE2_KEY}.AuthorizationForRepActClaimantsBehalf[0]": data.consent_address_change == true ? 1 : 0,
            # Condtions of Appointment
            "#{PAGE3_KEY}.LIMITATIONS[0]": data.conditions_of_appointment.join(', ')
          }
        end

        def header_options(data)
          {
            # Page 2
            # Header Veteran SSN
            "#{PAGE2_KEY}.SocialSecurityNumber_FirstThreeNumbers[1]": data.veteran_social_security_number[0..2],
            "#{PAGE2_KEY}.SocialSecurityNumber_SecondTwoNumbers[1]": data.veteran_social_security_number[3..4],
            "#{PAGE2_KEY}.SocialSecurityNumber_LastFourNumbers[1]": data.veteran_social_security_number[5..8],
            # Page 3
            # Header Veteran SSN
            "#{PAGE3_KEY}.SocialSecurityNumber_FirstThreeNumbers[2]": data.veteran_social_security_number[0..2],
            "#{PAGE3_KEY}.SocialSecurityNumber_SecondTwoNumbers[2]": data.veteran_social_security_number[3..4],
            "#{PAGE3_KEY}.SocialSecurityNumber_LastFourNumbers[2]": data.veteran_social_security_number[5..8]
          }
        end

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
            'VSO_REPRESENTATIVE' => 2
          }
          representative_type_map[representative_type]
        end

        def limitations_of_consent_text(consent_limits)
          limitations = {
            'ALCOHOLISM' => 'Alcoholism and alcohol abuse records',
            'DRUG_ABUSE' => 'Drug abuse records',
            'HIV' => 'HIV records',
            'SICKLE_CELL' => 'Sickle cell anemia records'
          }
          consent_text = consent_limits.filter_map { |limit| limitations[limit] }.to_sentence
          consent_text.presence || "No, they can't access any of these types of records."
        end
      end
    end
  end
end
