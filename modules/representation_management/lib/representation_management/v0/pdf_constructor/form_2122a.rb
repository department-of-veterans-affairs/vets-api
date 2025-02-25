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
          false
        end

        def next_steps_part1(pdf)
          add_text_with_spacing(pdf,
                                'Request help from a VA accredited representative or VSO', size: 20,
                                                                                           style: :bold)
          add_text_with_spacing(pdf, 'VA Form 21-22a')
          add_text_with_spacing(pdf, 'Your Next Steps', size: 16, style: :bold)
          str = <<~HEREDOC.squish
            Both you and the accredited representative will need to sign your form.
            You can bring your form to them in person or mail it to them.
          HEREDOC
          add_text_with_spacing(pdf, str, move_down: 30, font: 'soursesanspro')
        end

        def next_steps_contact(pdf, data)
          rep_name = <<~HEREDOC.squish
            #{data.representative.first_name}
            #{data.representative.middle_initial}
            #{data.representative.last_name}
          HEREDOC
          add_text_with_spacing(pdf, rep_name, style: :bold, move_down: 8)
          pdf.font('soursesanspro') do
            pdf.text(data.representative.address_line1)
            pdf.text(data.representative.address_line2)
            city_state_zip = <<~HEREDOC.squish
              #{data.representative.city},
              #{data.representative.state_code}
              #{data.representative.zip_code}
            HEREDOC
            pdf.text(city_state_zip)
            pdf.move_down(5)
            pdf.text(format_phone_number(data.representative_phone))
            pdf.text(data.representative.email)
          end
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
            "#{PAGE1_KEY}.Date_Of_Birth_Month[0]": data.veteran_date_of_birth.split('-').second,
            "#{PAGE1_KEY}.Date_Of_Birth_Day[0]": data.veteran_date_of_birth.split('-').last,
            "#{PAGE1_KEY}.Date_Of_Birth_Year[0]": data.veteran_date_of_birth.split('-').first,
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
            "#{PAGE1_KEY}.MailingAddress_StateOrProvince[0]": data.veteran_state_code_truncated,
            "#{PAGE1_KEY}.MailingAddress_Country[0]": data.veteran_country,
            "#{PAGE1_KEY}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]": data.veteran_zip_code_expanded.first,
            "#{PAGE1_KEY}.MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]": data.veteran_zip_code_expanded.second,
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
            "#{PAGE1_KEY}.Claimants_Date_Of_Birth_Month[0]": data.claimant_date_of_birth.split('-').second,
            "#{PAGE1_KEY}.Date_Of_Birth_Day[1]": data.claimant_date_of_birth.split('-').last,
            "#{PAGE1_KEY}.Date_Of_Birth_Year[1]": data.claimant_date_of_birth.split('-').first,
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
            "#{PAGE1_KEY}.MailingAddress_StateOrProvince[1]": data.claimant_state_code_truncated,
            "#{PAGE1_KEY}.MailingAddress_Country[1]": data.claimant_country,
            "#{PAGE1_KEY}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]": data.claimant_zip_code_expanded.first,
            "#{PAGE1_KEY}.MailingAddress_ZIPOrPostalCode_LastFourNumbers[1]": data.claimant_zip_code_expanded.second,
            # Claimant Phone Number
            "#{PAGE1_KEY}.Telephone_Number_Area_Code[0]": data.claimant_phone[0..2],
            "#{PAGE1_KEY}.Telphone_Middle_Three_Numbers[0]": data.claimant_phone[3..5],
            "#{PAGE1_KEY}.Telephone_Last_Four_Numbers[0]": data.claimant_phone[6..9],
            # Claimant Email
            "#{PAGE1_KEY}.E_Mail_Address_Optional[0]": data.claimant_email
          }
        end

        def representative_identification(data)
          rep_first_name_key = 'Name_Of_Individual_Appointed_As_Representative_First_Name[0]'
          {
            # Representative Name
            "#{PAGE1_KEY}.#{rep_first_name_key}": data.representative_field_truncated(:first_name),
            "#{PAGE1_KEY}.Middle_Initial[0]": data.representative_field_truncated(:middle_initial),
            "#{PAGE1_KEY}.Last_Name[0]": data.representative_field_truncated(:last_name),
            # Representative Type
            "#{PAGE1_KEY}.RadioButtonList[0]": representative_type_checkbox(
              data.representative_individual_type.to_s.upcase
            )
          }
        end

        def representative_contact_details(data)
          rep_phone_number = unformat_phone_number(data.representative_phone) || ''
          {
            # Representative Mailing Address
            "#{PAGE2_KEY}.MailingAddress_NumberAndStreet[2]": data.representative_field_truncated(:address_line1),
            "#{PAGE2_KEY}.MailingAddress_ApartmentOrUnitNumber[2]": data.representative_field_truncated(:address_line2),
            "#{PAGE2_KEY}.MailingAddress_City[2]": data.representative_field_truncated(:city),
            "#{PAGE2_KEY}.MailingAddress_StateOrProvince[2]": data.representative_field_truncated(:state_code),
            "#{PAGE2_KEY}.MailingAddress_Country[2]": normalize_country_code_to_alpha2(
              data.representative.country_code_iso3
            ),
            "#{PAGE2_KEY}.MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[2]": data.representative_zip_code_expanded[0],
            "#{PAGE2_KEY}.MailingAddress_ZIPOrPostalCode_LastFourNumbers[2]": data.representative_zip_code_expanded[1],
            # Representative Phone Number
            "#{PAGE2_KEY}.Telephone_Number_Area_Code[2]": rep_phone_number[0..2],
            "#{PAGE2_KEY}.Telephone_Middle_Three_Numbers[1]": rep_phone_number[3..5],
            "#{PAGE2_KEY}.Telephone_Last_Four_Numbers[2]": rep_phone_number[6..9],
            # Representative Email
            "#{PAGE2_KEY}.E_Mail_Address_Of_Individual_Appointed_As_Claimants_Representative_Optional[0]": \
            data.representative_field_truncated(:email)
          }
        end

        # rubocop:disable Layout/LineLength
        # Disabled due to two extremely long keys.
        def appointment_options(data)
          {
            # Record Consent
            "#{PAGE2_KEY}.AuthorizationForRepAccessToRecords[0]": data.record_consent == true ? 1 : 0,
            # Consent Limits
            "#{PAGE2_KEY}.RelationshipToVeteran[1]": limitations_of_consent_text(data.consent_limits,
                                                                                 data.record_consent),
            # Consent Address Change
            "#{PAGE2_KEY}.AuthorizationForRepActClaimantsBehalf[0]": data.consent_address_change == true ? 1 : 0,
            # 19a Consent Inside Access
            "#{PAGE2_KEY}.Checkbox_I_Authorize_VA_To_Disclose_All_My_Records_Other_Than_As_Provided_In_Items_20_And_21[0]": data.consent_inside_access == true ? 1 : 0,
            # 19a text box - This is commented for now because we're not gathering this data on the frontend but I
            # didn't want to lose the key.
            # "#{PAGE2_KEY}.Provide_The_Name_Of_The_Firm_Or_Organization_Here[0]": data.consent_team_members.to_sentence,
            # 19b Consent Outside Access
            "#{PAGE2_KEY}.Checkbox_I_Authorize_VA_To_Disclose_All_My_Records_Other_Than_As_Provided_In_Items_20_And_21[1]": data.consent_outside_access == true ? 1 : 0,
            # 19b text box
            "#{PAGE2_KEY}.Provide_The_Names_Of_The_Individuals_Here[0]": data.consent_team_members&.to_sentence
          }
        end
        # rubocop:enable Layout/LineLength

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

        def limitations_of_consent_text(consent_limits, record_consent)
          return '' unless record_consent && consent_limits.present?

          limitations = {
            'ALCOHOLISM' => 'Alcoholism and alcohol abuse records',
            'DRUG_ABUSE' => 'Drug abuse records',
            'HIV' => 'HIV records',
            'SICKLE_CELL' => 'Sickle cell anemia records'
          }
          authorized_limitations = consent_limits.filter_map { |limit| limitations[limit] }.to_sentence
          "I authorize access to: #{authorized_limitations}."
        end

        def normalize_country_code_to_alpha2(country_code)
          if country_code.present?
            IsoCountryCodes.find(country_code).alpha2
          else
            ''
          end
        end
      end
    end
  end
end
