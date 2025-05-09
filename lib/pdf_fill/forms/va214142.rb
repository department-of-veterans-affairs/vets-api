# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'

module PdfFill
  module Forms
    class Va214142 < FormBase
      include FormHelper

      PROVIDER_ITERATOR = PdfFill::HashConverter::ITERATOR
      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'F[0].Page_1[0].VeteranFirstName[0]',
            limit: 12,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'F[0].Page_1[0].VeteranMiddleInitial1[0]'
          },
          'last' => {
            key: 'F[0].Page_1[0].VeteranLastName[0]',
            limit: 18,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].Page_1[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].Page_1[0].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'vaFileNumber' => {
          key: 'F[0].Page_1[0].VAFileNumber[0]'
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'F[0].Page_1[0].DOBmonth[0]'
          },
          'day' => {
            key: 'F[0].Page_1[0].DOBday[0]'
          },
          'year' => {
            key: 'F[0].Page_1[0].DOByear[0]'
          }
        },
        'veteranServiceNumber' => {
          key: 'F[0].Page_1[0].VeteransServiceNumber_If_Applicable[0]'
        },
        'veteranAddress' => {
          question_num: 6,
          question_text: 'MAILING ADDRESS',

          'street' => {
            key: 'F[0].Page_1[0].MailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'Number and Street'
          },
          # TODO: Confirm that extra page is created for "See additional" when apt/unit number is used
          'street2' => {
            key: 'F[0].Page_1[0].MailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'Apartment or Unit Number'
          },
          'city' => {
            key: 'F[0].Page_1[0].MailingAddress_City[0]',
            limit: 18,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'City'
          },
          'state' => {
            key: 'F[0].Page_1[0].MailingAddress_StateOrProvince[0]'
          },
          'country' => {
            key: 'F[0].Page_1[0].MailingAddress_Country[0]',
            limit: 2
          },
          'postalCode' => {
            'firstFive' => {
              key: 'F[0].Page_1[0].MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            },
            'lastFour' => {
              key: 'F[0].Page_1[0].MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
            }
          }
        },
        # TODO: 2018 form had one field for phone number, the 2024 form has 3 fields. Need to create a object similar to social security.
        'veteranPhone' => {
          'first' => {
            key: 'F[0].Page_1[0].TelephoneNumber_AreaCode[0]'
          },
          'second' => {
            key: 'F[0].Page_1[0].TelephoneNumber_SecondThreeNumbers[0]'
          },
          'third' => {
            key: 'F[0].Page_1[0].TelephoneNumber_LastFourNumbers[0]'
          }
        },
        # TODO
        'internationalPhoneNumber' => {
          key: 'F[0].Page_1[0].International_Telephone_Number_If_Applicable[0]'
        },
        'email' => {
          key: 'F[0].Page_1[0].E_Mail_Address[0]'
        },
        'veteranSocialSecurityNumber1' => {
          'first' => {
            key: 'F[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].#subform[1].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'limitedConsent' => {
          limit: 83,
          question_num: 12,
          question_text: 'Limited Consent',
          key: 'F[0].#subform[1].InformationIsLimitedToWhatIsWrittenInThisSpace[0]'
        },
        # NOTE: Signature field is not populating F[0].#subform[1].SignatureField11[0]
        'signature' => {
          key: 'F[0].#subform[1].SignatureField11[0]'
        },
        # TODO: 2018 form had one field for signature date, the 2024 form has 3 fields. Need to create a object similar to social security.
        'signatureDate' => {
          key: 'F[0].#subform[1].DateSigned_Month_Day_Year[0]',
          format: 'date'
        },
        # TODO: 2018 form had one field for printed name, the 2024 form has 3 fields. Need to create a object similar to social security.
        'printedName' => {
          key: 'F[0].#subform[1].PrintedNameOfPersonAuthorizingDisclosure[0]'
        },
        'veteranFullName1' => {
          'first' => {
            key: 'F[0].#subform[14].VeteranFirstName[0]',
            limit: 12,
            question_num: 17,
            question_text: "4142a VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'F[0].#subform[14].VeteranMiddleInitial1[0]'
          },
          'last' => {
            key: 'F[0].#subform[14].VeteranLastName[0]',
            limit: 18,
            question_num: 17,
            question_text: "4142a VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'F[0].#subform[14].SSN1[0]'
          },
          'second' => {
            key: 'F[0].#subform[14].SSN2[0]'
          },
          'third' => {
            key: 'F[0].#subform[14].SSN3[0]'
          }
        },
        # NOTE: This is field is not populating F[0].#subform[14].VAFileNumber[0] is the new field in the 2024 form
        'vaFileNumber1' => {
          key: 'F[0].#subform[14].VAFileNumber[0]'
        },
        'veteranDateOfBirth1' => {
          'month' => {
            key: 'F[0].#subform[14].Month[0]'
          },
          'day' => {
            key: 'F[0].#subform[14].Day[0]'
          },
          'year' => {
            key: 'F[0].#subform[14].Year[0]'
          }
        },
        'veteranServiceNumber1' => {
          key: 'F[0].#subform[14].VeteransServiceNumber_If_Applicable[0]'
        },
        'veteranSocialSecurityNumber3' => {
          'first' => {
            key: 'F[0].#subform[14].FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].#subform[14].SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].#subform[14].LastFourNumbers[0]'
          }
        },
        'providerFacility' => {
          limit: 5,
          first_key: 'providerFacilityName',
          question_text: 'PROVIDER / FACILITY',

          'providerFacilityName' => {
            key: "F[0].provider.Provider_Or_Facility_Name[#{PROVIDER_ITERATOR}]"
          },
          'dateRangeStart0' => {
            key: "F[0].provider.dateRangeStart0[#{PROVIDER_ITERATOR}]",
            format: 'date'
          },
          'dateRangeEnd0' => {
            key: "F[0].provider.dateRangeEnd0[#{PROVIDER_ITERATOR}]",
            format: 'date'
          },
          'dateRangeStart1' => {
            key: "F[0].provider.dateRangeStart1[#{PROVIDER_ITERATOR}]",
            format: 'date'
          },
          'dateRangeEnd1' => {
            key: "F[0].provider.dateRangeEnd1[#{PROVIDER_ITERATOR}]",
            format: 'date'
          },
          'street' => {
            limit: 30,
            key: "F[0].provider.numberAndStreet[#{PROVIDER_ITERATOR}]"
          },
          'street2' => {
            limit: 5,
            key: "F[0].provider.apartmentOrUnitNumber[#{PROVIDER_ITERATOR}]"
          },
          'city' => {
            limit: 18,
            key: "F[0].provider.city[#{PROVIDER_ITERATOR}]"
          },
          'state' => {
            key: "F[0].provider.state[#{PROVIDER_ITERATOR}]"
          },
          'country' => {
            key: "F[0].provider.country[#{PROVIDER_ITERATOR}]"
          },
          'postalCode' => {
            'firstFive' => {
              key: "F[0].provider.postalCode_FirstFiveNumbers[#{PROVIDER_ITERATOR}]"
            },
            'lastFour' => {
              key: "F[0].provider.postalCode_LastFourNumbers[#{PROVIDER_ITERATOR}]"
            }
          },
          'nameAndAddressOfProvider' => {
            key: '',
            question_suffix: 'A',
            question_text: 'Name and Address of Provider',
            question_num: 9
          },
          'combinedTreatmentDates' => {
            key: '',
            question_suffix: 'B',
            question_text: 'Treatment Dates',
            question_num: 9
          }
        }
      }.freeze

      def expand_va_file_number
        va_file_number = @form_data['vaFileNumber']
        return if va_file_number.blank?

        ['', '1'].each do |suffix|
          @form_data["vaFileNumber#{suffix}"] = va_file_number
        end
      end

      def expand_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        return if ssn.blank?

        ['', '1', '2', '3'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
        end
      end

      def expand_phone_number
        phone = @form_data['veteranPhone']
        return if phone.blank?

        ['', '1', '2', '3'].each do |suffix|
          @form_data["veteranPhone#{suffix}"] = split_phone_number(phone)
        end
      end

      def expand_claimant_address
        @form_data['veteranAddress']['country'] = extract_country(@form_data['veteranAddress'])
        @form_data['veteranAddress']['postalCode'] = split_postal_code(@form_data['veteranAddress'])
      end

      def expand_veteran_full_name
        ['', '1'].each do |suffix|
          @form_data["veteranFullName#{suffix}"] = extract_middle_i(@form_data, 'veteranFullName')
        end
      end

      def expand_veteran_dob
        veteran_date_of_birth = @form_data['veteranDateOfBirth']
        return if veteran_date_of_birth.blank?

        ['', '1'].each do |suffix|
          @form_data["veteranDateOfBirth#{suffix}"] = split_date(veteran_date_of_birth)
        end
      end

      def expand_veteran_service_number
        veteran_service_number = @form_data['veteranServiceNumber']
        return if veteran_service_number.blank?

        if veteran_service_number
          ['', '1'].each do |suffix|
            @form_data["veteranServiceNumber#{suffix}"] = veteran_service_number
          end
        end
      end

      def expand_provider_date_range(providers)
        providers.each do |provider|
          dates_of_treatment = provider['treatmentDateRange']
          date_ranges = {}
          dates_of_treatment.each_with_index do |date_range, index|
            date_ranges.merge!(
              "dateRangeStart#{index}" => date_range['from'],
              "dateRangeEnd#{index}" => date_range['to']
            )
          end
          provider.except!('treatmentDateRange')
          provider.merge!(date_ranges)
        end
      end

      def expand_provider_address(providers)
        providers.each do |provider|
          provider_address = {
            'street' => provider['providerFacilityAddress']['street'],
            'street2' => provider['providerFacilityAddress']['street2'],
            'city' => provider['providerFacilityAddress']['city'],
            'state' => provider['providerFacilityAddress']['state'],
            'country' => extract_country(provider['providerFacilityAddress']),
            'postalCode' => split_postal_code(provider['providerFacilityAddress'])
          }
          provider.except!('providerFacilityAddress')
          provider.merge!(provider_address)
        end
      end

      def expand_provider_extras(providers)
        providers.each do |provider|
          name_address_extras = combine_name_addr_extras(provider, 'providerFacilityName', 'providerFacilityAddress')
          provider['nameAndAddressOfProvider'] = PdfFill::FormValue.new('', name_address_extras)
          dates_extras = combine_date_ranges(provider['treatmentDateRange'])
          provider['combinedTreatmentDates'] = PdfFill::FormValue.new('', dates_extras)
        end
      end

      def expand_providers(providers)
        return if providers.blank?

        expand_provider_extras(providers)
        expand_provider_address(providers)
        expand_provider_date_range(providers)
      end

      def merge_fields(_options = {})
        expand_va_file_number

        expand_ssn
        expand_phone_number

        expand_veteran_full_name
        signature_date = @form_data['signatureDate']
        expand_signature(@form_data['veteranFullName'], signature_date)
        @form_data['printedName'] = @form_data['signature']
        @form_data['signature'] = "/es/ #{@form_data['signature']}"

        expand_claimant_address

        expand_veteran_dob

        expand_veteran_service_number

        @form_data['providerFacility'] = expand_providers(@form_data['providerFacility'])

        @form_data
      end
    end
  end
end


# F[0].Page_1[0].VeteranFirstName[0]
# F[0].Page_1[0].VeteranMiddleInitial1[0]
# F[0].Page_1[0].VeteranLastName[0]
# F[0].Page_1[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]
# F[0].Page_1[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]
# F[0].Page_1[0].VeteransSocialSecurityNumber_LastFourNumbers[0]
# F[0].Page_1[0].VAFileNumber[0]
# F[0].Page_1[0].DOBmonth[0]
# F[0].Page_1[0].DOBday[0]
# F[0].Page_1[0].DOByear[0]
# F[0].Page_1[0].VeteransServiceNumber_If_Applicable[0]
# F[0].Page_1[0].MailingAddress_NumberAndStreet[0]
# F[0].Page_1[0].MailingAddress_ApartmentOrUnitNumber[0]
# F[0].Page_1[0].MailingAddress_City[0]
# F[0].Page_1[0].MailingAddress_StateOrProvince[0]
# F[0].Page_1[0].MailingAddress_Country[0]
# F[0].Page_1[0].MailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]
# F[0].Page_1[0].MailingAddress_ZIPOrPostalCode_LastFourNumbers[0]
# F[0].Page_1[0].TelephoneNumber_AreaCode[0]
# F[0].Page_1[0].TelephoneNumber_SecondThreeNumbers[0]
# F[0].Page_1[0].TelephoneNumber_LastFourNumbers[0]
# F[0].Page_1[0].International_Telephone_Number_If_Applicable[0]
# F[0].Page_1[0].CheckBox1[0]
# F[0].Page_1[0].E_Mail_Address[0]
# F[0].Page_1[0].E_Mail_Address[1]
# F[0].Page_1[0].Patients_FirstName[0]
# F[0].Page_1[0].Patients_MiddleInitial1[0]
# F[0].Page_1[0].Patients_LastName[0]
# F[0].Page_1[0].Patient_SocialSecurityNumber_FirstThreeNumbers[0]
# F[0].Page_1[0].Patient_SocialSecurityNumber_SecondTwoNumbers[0]
# F[0].Page_1[0].Patient_SocialSecurityNumber_LastFourNumbers[0]
# F[0].Page_1[0].Patients_VAFileNumber_If_Applicable[0]
# F[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[0]
# F[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[0]
# F[0].#subform[1].VeteransSocialSecurityNumber_LastFourNumbers[0]
# F[0].#subform[1].InformationIsLimitedToWhatIsWrittenInThisSpace[0]
# F[0].#subform[1].SignatureField11[0]
# F[0].#subform[1].Date_Signed_Month[0]
# F[0].#subform[1].Date_Signed_Day[0]
# F[0].#subform[1].Date_Signed_Year[0]
# F[0].#subform[1].Printed_Name_Of_Person_Signing_First[0]
# F[0].#subform[1].Printed_Name_Of_Person_Signing_Middle_Initial[0]
# F[0].#subform[1].Printed_Name_Of_Person_Signing_Last[0]
# F[0].#subform[1].Relationship_To_Veteran_Claimant[0]
# F[0].#subform[14].VeteranFirstName[0]
# F[0].#subform[14].VeteranMiddleInitial1[0]
# F[0].#subform[14].VeteranLastName[0]
# F[0].#subform[14].SSN1[0]
# F[0].#subform[14].SSN2[0]
# F[0].#subform[14].SSN3[0]
# F[0].#subform[14].VAFileNumber[0]
# F[0].#subform[14].Month[0]
# F[0].#subform[14].Day[0]
# F[0].#subform[14].Year[0]
# F[0].#subform[14].VeteransServiceNumber_If_Applicable[0]
# F[0].#subform[14].Patients_FirstName[0]
# F[0].#subform[14].PatientMiddleInitial1[0]
# F[0].#subform[14].Patients_LastName[0]
# F[0].#subform[14].FirstThreeNumbers[0]
# F[0].#subform[14].SecondTwoNumbers[0]
# F[0].#subform[14].LastFourNumbers[0]
# F[0].#subform[14].VAFileNumber[1]
# F[0].#subform[14].Provider_Or_Facility_Name[0]
# F[0].#subform[14].Conditions_You_Are_Being_Treated_For[0]
# F[0].#subform[14].Month[1]
# F[0].#subform[14].Day[1]
# F[0].#subform[14].Year[1]
# F[0].#subform[14].Month[2]
# F[0].#subform[14].Day[2]
# F[0].#subform[14].Year[2]
# F[0].#subform[14].Provider_Facility_Street_Address_NumberAndStreet[0]
# F[0].#subform[14].MailingAddress_ApartmentOrUnitNumber[0]
# F[0].#subform[14].Provider_Facility_Address_City[0]
# F[0].#subform[14].Provider_Facility_Address_StateOrProvince[0]
# F[0].#subform[14].Provider_Facility_Address_Country[0]
# F[0].#subform[14].Provider_Facility_Address_ZIPOrPostalCode_FirstFiveNumbers[0]
# F[0].#subform[14].Provider_Facility_Address_ZIPOrPostalCode_LastFourNumbers[0]
# F[0].#subform[14].Provider_Or_Facility_Name[1]
# F[0].#subform[14].Conditions_You_Are_Being_Treated_For[1]
# F[0].#subform[14].Month[3]
# F[0].#subform[14].Day[3]
# F[0].#subform[14].Year[3]
# F[0].#subform[14].Month[4]
# F[0].#subform[14].Day[4]
# F[0].#subform[14].Year[4]
# F[0].#subform[14].Provider_Facility_Street_Address_NumberAndStreet[1]
# F[0].#subform[14].MailingAddress_ApartmentOrUnitNumber[1]
# F[0].#subform[14].Provider_Facility_Address_City[1]
# F[0].#subform[14].Provider_Facility_Address_StateOrProvince[1]
# F[0].#subform[14].Provider_Facility_Address_Country[1]
# F[0].#subform[14].Provider_Facility_Address_ZIPOrPostalCode_FirstFiveNumbers[1]
# F[0].#subform[14].Provider_Facility_Address_ZIPOrPostalCode_LastFourNumbers[1]
# F[0].#subform[15].SSN1[1]
# F[0].#subform[15].SSN2[1]
# F[0].#subform[15].SSN3[1]
# F[0].#subform[15].Provider_Or_Facility_Name[2]
# F[0].#subform[15].Conditions_You_Are_Being_Treated_For[2]
# F[0].#subform[15].Month[5]
# F[0].#subform[15].Day[5]
# F[0].#subform[15].Year[5]
# F[0].#subform[15].Month[6]
# F[0].#subform[15].Day[6]
# F[0].#subform[15].Year[6]
# F[0].#subform[15].Provider_Facility_Street_Address_NumberAndStreet[2]
# F[0].#subform[15].MailingAddress_ApartmentOrUnitNumber[2]
# F[0].#subform[15].Provider_Facility_Address_City[2]
# F[0].#subform[15].Provider_Facility_Address_StateOrProvince[2]
# F[0].#subform[15].Provider_Facility_Address_Country[2]
# F[0].#subform[15].Provider_Facility_Address_ZIPOrPostalCode_FirstFiveNumbers[2]
# F[0].#subform[15].Provider_Facility_Address_ZIPOrPostalCode_LastFourNumbers[2]
# F[0].#subform[15].Provider_Or_Facility_Name[3]
# F[0].#subform[15].Conditions_You_Are_Being_Treated_For[3]
# F[0].#subform[15].Month[7]
# F[0].#subform[15].Day[7]
# F[0].#subform[15].Year[7]
# F[0].#subform[15].Month[8]
# F[0].#subform[15].Day[8]
# F[0].#subform[15].Year[8]
# F[0].#subform[15].Provider_Facility_Street_Address_NumberAndStreet[3]
# F[0].#subform[15].MailingAddress_ApartmentOrUnitNumber[3]
# F[0].#subform[15].Provider_Facility_Address_City[3]
# F[0].#subform[15].Provider_Facility_Address_StateOrProvince[3]
# F[0].#subform[15].Provider_Facility_Address_Country[3]
# F[0].#subform[15].Provider_Facility_Address_ZIPOrPostalCode_FirstFiveNumbers[3]
# F[0].#subform[15].Provider_Facility_Address_ZIPOrPostalCode_LastFourNumbers[3]
# F[0].#subform[15].Provider_Or_Facility_Name[4]
# F[0].#subform[15].Conditions_You_Are_Being_Treated_For[4]
# F[0].#subform[15].Month[9]
# F[0].#subform[15].Day[9]
# F[0].#subform[15].Year[9]
# F[0].#subform[15].Month[10]
# F[0].#subform[15].Day[10]
# F[0].#subform[15].Year[10]
# F[0].#subform[15].Provider_Facility_Street_Address_NumberAndStreet[4]
# F[0].#subform[15].MailingAddress_ApartmentOrUnitNumber[4]
# F[0].#subform[15].Provider_Facility_Address_City[4]
# F[0].#subform[15].Provider_Facility_Address_StateOrProvince[4]
# F[0].#subform[15].Provider_Facility_Address_Country[4]
# F[0].#subform[15].Provider_Facility_Address_ZIPOrPostalCode_FirstFiveNumbers[4]
# F[0].#subform[15].Provider_Facility_Address_ZIPOrPostalCode_LastFourNumbers[4]