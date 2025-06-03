# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'

module PdfFill
  module Forms
    class Va2141422024 < FormBase
      include FormHelper

      # rubocop:disable Metrics/BlockLength

      # rubocop:disable Layout/LineLength

      # The 2024 keys for the provider fields can no longer use the straightforward ITERATOR
      # provided by HashConverter, so we do it ourselves here to map them correctly
      PROVIDER_KEYS = (0..4).each_with_object({}) do |provider_index, keys|
        question_num = provider_index + 9 # 9, 10, 11, 12, 13

        # Determine subform number based on provider index
        subform_num = provider_index <= 1 ? 14 : 15

        # Calculate date field indices (1,2 then 3,4 then 5,6 then 7,8 then 9,10)
        date_start_index = (provider_index * 2) + 1
        date_end_index = date_start_index + 1

        # 1-based array indexing seems more intuitive here
        keys["provider#{provider_index + 1}"] = {
          'providerFacilityName' => {
            limit: 100,
            key: "F[0].#subform[#{subform_num}].Provider_Or_Facility_Name[#{provider_index}]",
            question_num:,
            question_suffix: 'A',
            question_text: 'Provider or Facility Name',
            hide_from_overflow: true
          },
          'conditionsTreated' => {
            limit: 100,
            key: "F[0].#subform[#{subform_num}].Conditions_You_Are_Being_Treated_For[#{provider_index}]",
            question_num:,
            question_suffix: 'B',
            question_text: 'Conditions Being Treated For',
            hide_from_overflow: true
          },
          'dateRangeStart' => {
            'month' => {
              key: "F[0].#subform[#{subform_num}].Month[#{date_start_index}]"
            },
            'day' => {
              key: "F[0].#subform[#{subform_num}].Day[#{date_start_index}]"
            },
            'year' => {
              key: "F[0].#subform[#{subform_num}].Year[#{date_start_index}]"
            }
          },
          'dateRangeEnd' => {
            'month' => {
              key: "F[0].#subform[#{subform_num}].Month[#{date_end_index}]"
            },
            'day' => {
              key: "F[0].#subform[#{subform_num}].Day[#{date_end_index}]"
            },
            'year' => {
              key: "F[0].#subform[#{subform_num}].Year[#{date_end_index}]"
            }
          },
          'address' => {
            first_key: 'street',
            limit: 1,
            question_num:,
            question_suffix: 'D',
            question_text: 'Provider or Facility Address',
            'street' => {
              limit: 30,
              key: "F[0].#subform[#{subform_num}].Provider_Facility_Street_Address_NumberAndStreet[#{provider_index}]",
              question_num:,
              question_suffix: 'D-1',
              question_text: 'Street',
              hide_from_overflow: true
            },
            'street2' => {
              limit: 5,
              key: "F[0].#subform[#{subform_num}].MailingAddress_ApartmentOrUnitNumber[#{provider_index}]",
              question_num:,
              question_suffix: 'D-2',
              question_text: 'Street 2',
              hide_from_overflow: true
            },
            'city' => {
              limit: 18,
              key: "F[0].#subform[#{subform_num}].Provider_Facility_Address_City[#{provider_index}]",
              question_num:,
              question_suffix: 'D-3',
              question_text: 'City',
              hide_from_overflow: true
            },
            'state' => {
              key: "F[0].#subform[#{subform_num}].Provider_Facility_Address_StateOrProvince[#{provider_index}]",
              question_num:,
              question_suffix: 'D-4',
              question_text: 'State',
              hide_from_overflow: true
            },
            'country' => {
              key: "F[0].#subform[#{subform_num}].Provider_Facility_Address_Country[#{provider_index}]",
              question_num:,
              question_suffix: 'D-5',
              question_text: 'Country',
              hide_from_overflow: true
            },
            'postalCode' => {
              'firstFive' => {
                key: "F[0].#subform[#{subform_num}].Provider_Facility_Address_ZIPOrPostalCode_FirstFiveNumbers[#{provider_index}]",
                question_num:,
                question_suffix: 'D-6',
                question_text: 'Postal Code: First 5',
                hide_from_overflow: true
              },
              'lastFour' => {
                key: "F[0].#subform[#{subform_num}].Provider_Facility_Address_ZIPOrPostalCode_LastFourNumbers[#{provider_index}]",
                question_num:,
                question_suffix: 'D-7',
                question_text: 'Postal Code: Last 4',
                hide_from_overflow: true
              }
            }
          },
          'completeProviderInfo' => {
            key: 'DUMMY_KEY_TO_ALLOW_OVERFLOW',
            limit: 1,
            always_overflow: true,
            question_text: 'Provider or Facility and Treatment Info',
            question_num:,
            question_suffix: 'A-D',
            skip_index: true
          }
        }
      end.freeze

      # rubocop:enable Metrics/BlockLength

      # rubocop:enable Layout/LineLength

      # Used when there are > 5 providers, so we can format them nicely on the overflow pages
      ADDITIONAL_PROVIDER_KEYS = (6..50).each_with_object({}) do |provider_num, keys|
        # Starts at 14 since the last provider on the PDF is question 13
        question_num = provider_num + 8
        keys["additionalProvider#{provider_num}"] = {
          'completeProviderInfo' => {
            key: 'DUMMY_KEY_TO_ALLOW_OVERFLOW',
            limit: 1,
            always_overflow: true,
            question_text: 'Provider or Facility and Treatment Info',
            question_num:,
            question_suffix: 'A-D',
            skip_index: true
          }
        }
      end.freeze

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
        'veteranPhone' => {
          'phone_area_code' => {
            key: 'F[0].Page_1[0].TelephoneNumber_AreaCode[0]'
          },
          'phone_first_three_numbers' => {
            key: 'F[0].Page_1[0].TelephoneNumber_SecondThreeNumbers[0]'
          },
          'phone_last_four_numbers' => {
            key: 'F[0].Page_1[0].TelephoneNumber_LastFourNumbers[0]'
          }
        },
        'internationalPhoneNumber' => {
          key: 'F[0].Page_1[0].International_Telephone_Number_If_Applicable[0]'
        },
        'email' => {
          key: 'F[0].Page_1[0].E_Mail_Address[0]',
          limit: 15, # We will only allow this to overflow if the overall email is too long
          question_text: 'E-mail Address',
          question_num: 8
        },
        'email1' => {
          key: 'F[0].Page_1[0].E_Mail_Address[1]'
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
        'signature' => {
          key: 'F[0].#subform[1].SignatureField11[0]'
        },
        'signatureDate' => {
          'month' => {
            key: 'F[0].#subform[1].Date_Signed_Month[0]'
          },
          'day' => {
            key: 'F[0].#subform[1].Date_Signed_Day[0]'
          },
          'year' => {
            key: 'F[0].#subform[1].Date_Signed_Year[0]'
          }
        },
        'printedName' => {
          'first' => {
            key: 'F[0].#subform[1].Printed_Name_Of_Person_Signing_First[0]',
            limit: 12,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'F[0].#subform[1].Printed_Name_Of_Person_Signing_Middle_Initial[0]'
          },
          'last' => {
            key: 'F[0].#subform[1].Printed_Name_Of_Person_Signing_Last[0]',
            limit: 18,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S LAST NAME"
          }
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
        'veteranSocialSecurityNumber3' => {
          'first' => {
            key: 'F[0].#subform[15].SSN1[1]'
          },
          'second' => {
            key: 'F[0].#subform[15].SSN2[1]'
          },
          'third' => {
            key: 'F[0].#subform[15].SSN3[1]'
          }
        },
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
        }
      }.merge(PROVIDER_KEYS).merge(ADDITIONAL_PROVIDER_KEYS).freeze

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

      def expand_printed_full_name
        ['', '1'].each do |suffix|
          @form_data["printedName#{suffix}"] = extract_middle_i(@form_data, 'veteranFullName')
        end
      end

      def expand_veteran_dob
        veteran_date_of_birth = @form_data['veteranDateOfBirth']
        return if veteran_date_of_birth.blank?

        ['', '1'].each do |suffix|
          @form_data["veteranDateOfBirth#{suffix}"] = split_date(veteran_date_of_birth)
        end
      end

      def expand_email_address
        email = @form_data['email']

        # The email field spans two lines with different PDF keys so we
        # need to split the email into two parts if between 15 and 30 chars
        if email.size > 15 && email.size <= 30
          @form_data['email'] = email[0..14]
          @form_data['email1'] = email[15..]
        end
      end

      def expand_signature_date
        veteran_signature_date = Date.strptime(@form_data['signatureDate'], '%Y-%m-%d').to_s
        return if veteran_signature_date.blank?

        @form_data['signatureDate'] = split_date(veteran_signature_date)
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
          dates_of_treatment.each do |date_range|
            date_ranges.merge!(
              'dateRangeStart' => split_date(date_range['from']),
              'dateRangeEnd' => split_date(date_range['to'])
            )
          end

          provider.merge!(date_ranges)
        end
      end

      def expand_provider_address(providers)
        providers.each do |provider|
          address = {
            'street' => provider['providerFacilityAddress']['street'],
            'street2' => provider['providerFacilityAddress']['street2'],
            'city' => provider['providerFacilityAddress']['city'],
            'state' => provider['providerFacilityAddress']['state'],
            'country' => extract_country(provider['providerFacilityAddress']),
            'postalCode' => split_postal_code(provider['providerFacilityAddress'])
          }

          # only fill out the completeAddress key (for the overflow page) if any of address fields are too long
          if address['street'].size > 30 || address['street2'].size > 5 || address['city'].size > 18
            provider['addressOverflows'] = true
          end

          # We need to put the address in an array to take advantage of hashConverter's
          # configuration options for overflowing the address properly
          provider['address'] = [address]
        end
      end

      def handle_provider_overflow(providers)
        first_four_no_overflow = true

        providers.each_with_index do |provider, index|
          if provider['addressOverflows'] ||
             (provider['providerFacilityName']&.size || 0) > 100 ||
             (provider['conditionsTreated']&.size || 0) > 100
            generate_overflow_provider_info(provider)
          end

          if index == 4 && first_four_no_overflow && providers.count > 5
            # Force the fifth provider to overflow, to cue the user to see the overflow page
            generate_overflow_provider_info(provider)
            provider['providerFacilityName'] = "See add'l info page"
          end

          # If we have more than 5 providers, we need to generate the overflow info
          generate_overflow_provider_info(provider) if index >= 5
        end
      end

      # rubocop:disable Layout/LineLength

      def generate_overflow_provider_info(provider)
        # Combine the provider name, address, and treatment dates into a single string for the overflow page
        address = combine_name_addr_extras(provider, 'providerFacilityName', 'providerFacilityAddress')
        dates = combine_date_ranges(provider['treatmentDateRange'])

        provider['completeProviderInfo'] = [PdfFill::FormValue.new(
          '',
          "Provider or Facility Name: #{provider['providerFacilityName']}\n\nAddress: #{address}\n\nConditions Treated: #{provider['conditionsTreated']}\n\nTreatment Date Ranges: #{dates}"
        )]
      end

      # rubocop:enable Layout/LineLength

      def expand_providers
        providers = @form_data['providerFacility']
        return if providers.blank?

        expand_provider_address(providers)
        expand_provider_date_range(providers)
        handle_provider_overflow(providers)

        # First 5 providers are mapped to the provider 1-5 keys
        # Any provider beyond 5, up to 50, goes to overflow pages, mapped to the additionalProvider6-50
        providers.each_with_index do |provider, index|
          if index < 5
            @form_data["provider#{index + 1}"] = provider
          else
            additional_provider_number = index + 1
            # Similar to address, we put the provider info in an array to take advantage of
            # hashConverter's configuration options for formatting the overflow pages
            @form_data["additionalProvider#{additional_provider_number}"] = provider
          end
        end

        # Remove the original providerFacility key from the resulting form_data hash
        @form_data.delete('providerFacility')
      end

      def merge_fields(_options = {})
        expand_va_file_number
        expand_email_address

        expand_ssn
        expand_phone_number

        expand_veteran_full_name
        expand_printed_full_name

        signature_date = @form_data['signatureDate']
        expand_signature(@form_data['veteranFullName'], signature_date)
        expand_signature_date
        @form_data['signature'] = "/es/ #{@form_data['signature']}"

        expand_claimant_address

        expand_veteran_dob

        expand_veteran_service_number

        expand_providers

        @form_data
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
