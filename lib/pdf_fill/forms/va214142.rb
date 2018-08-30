# frozen_string_literal: true

module PdfFill
  module Forms
    class Va214142 < FormBase
      include FormHelper

      PROVIDER_ITERATOR = PdfFill::HashConverter::ITERATOR
      PROVIDER_TREATMENT_DATE_ITERATOR = PdfFill::HashConverter::ITERATOR

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
            key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].Page_1[0].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
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
          key: 'F[0].Page_1[0].VeteransServiceNumber[0]'
        },
        'claimantAddress' => {
          question_num: 6,
          question_text: 'MAILING ADDRESS',

          'veteranAddressLine1' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'Number and Street'
          },
          'apartmentOrUnitNumber' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'Apartment or Unit Number'
          },
          'city' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_City[0]',
            limit: 18,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'City'
          },
          'state' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_StateOrProvince[0]'
          },
          'country' => {
            key: 'F[0].Page_1[0].CurrentMailingAddress_Country[0]',
            limit: 2
          },
          'postalCode' => {
            'firstFive' => {
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            },
            'lastFour' => {
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
            }
          }
        },
        'claimantEmail' => {
          key: 'F[0].Page_1[0].EMAIL[0]'
        },
        'claimantPhone' => {
          key: 'F[0].Page_1[0].EMAIL[1]'
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
          key: 'F[0].#subform[1].InformationIsLimitedToWhatIsWrittenInThisSpace[0]'
        },
        'signature' => {
          key: 'F[0].#subform[1].CLAIMANT_SIGNATURE[0]'
        },
        'signatureDate' => {
          key: 'F[0].#subform[1].DateSigned_Month_Day_Year[0]'
        },
        'printedName' => {
          key: 'F[0].#subform[1].PrintedNameOfPersonAuthorizingDisclosure[0]'
        },
        'veteranFullName1' => {
          'first' => {
            key: 'F[0].#subform[8].VeteranFirstName[0]',
            limit: 12,
            question_num: 17,
            question_text: "4142a VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'F[0].#subform[8].VeteranMiddleInitial1[0]'
          },
          'last' => {
            key: 'F[0].#subform[8].VeteranLastName[0]',
            limit: 18,
            question_num: 17,
            question_text: "4142a VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'F[0].#subform[8].ClaimantsSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'F[0].#subform[8].ClaimantsSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'F[0].#subform[8].ClaimantsSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'vaFileNumber1' => {
          key: 'F[0].#subform[8].VAFileNumber[0]'
        },
        'veteranDateOfBirth1' => {
          'month' => {
            key: 'F[0].#subform[8].DOBmonth[0]'
          },
          'day' => {
            key: 'F[0].#subform[8].DOBday[0]'
          },
          'year' => {
            key: 'F[0].#subform[8].DOByear[0]'
          }
        },
        'veteranServiceNumber1' => {
          key: 'F[0].#subform[8].VeteransServiceNumber[0]'
        },
        'veteranSocialSecurityNumber3' => {
          'first' => {
            key: 'F[0].#subform[9].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'F[0].#subform[9].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'F[0].#subform[9].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        'providerFacility' => {
          limit: 5,
          first_key: 'providerFacilityName',
          question_text: "PROVIDER / FACILITY",

          'providerFacilityName' => {
            key: "F[0].provider.name[#{PROVIDER_ITERATOR}]",
            question_text: 'PROVIDER / FACILITY NAME',
            question_num: 9,
            question_suffix: 'A'
          },
          'treatmentDateRange' => {
            question_text: "Treatment Date Range",
            limit: 2,
            'dateRangeStart' => {
              key: "F[#{PROVIDER_ITERATOR}].provider.datesOfTreatment.fromDate[0]",
              question_num: 9,
              question_text: 'Treatment Start Date',
              question_suffix: 'B'
            },
            'dateRangeEnd' => {
              key: "F[#{PROVIDER_ITERATOR}].provider.datesOfTreatment.toDate[0]",
              question_num: 9,
              question_text: 'Treatment End Date',
              question_suffix: 'C'
            },
            'dateRangeStart1' => {
              key: "F[#{PROVIDER_ITERATOR}].provider.datesOfTreatment.fromDate[1]",
              question_num: 9,
              question_text: 'Treatment End Date',
              question_suffix: 'D'
            },
            'dateRangeEnd1' => {
              key: "F[#{PROVIDER_ITERATOR}].provider.datesOfTreatment.toDate[1]",
              question_num: 9,
              question_text: 'Treatment End Date',
              question_suffix: 'E'
            }
          },
          'street' => {
            question_text: "Provider / Facility Street Address",
            question_num: 9,
              question_suffix: 'F',
              limit: 30,
              key: "F[0].provider.numberAndStreet[#{PROVIDER_ITERATOR}]"
          },
            'street2' => {
              question_text: "Provider / Facility Street Address 2",
              question_num: 9,
              question_suffix: 'G',
              limit: 5,
              key: "F[0].provider.apartmentOrUnitNumber[#{PROVIDER_ITERATOR}]"
            },
            'city' => {
              question_text: "Provider / Facility City",
              question_num: 9,
              question_suffix: 'H',
              limit: 18,
              key: "F[0].provider.city[#{PROVIDER_ITERATOR}]"
            },
            'state' => {
              question_text: "Provider / Facility State",
              question_num: 9,
              question_suffix: 'I',
              key: "F[0].provider.state[#{PROVIDER_ITERATOR}]"
            },
            'country' => {
              question_text: "Provider / Facility Country",
              question_num: 9,
              question_suffix: 'J',
              key: "F[0].provider.country[#{PROVIDER_ITERATOR}]"
            },
            'postalCode' => {
              question_text: "Provider Postal Code",
              'firstFive' => {
                question_text: "Provider / Facility Postal Code First Five",
                question_num: 9,
                question_suffix: 'K',
                key: "F[0].provider.postalCode_FirstFiveNumbers[#{PROVIDER_ITERATOR}]"
              },
              'lastFour' => {
                question_text: "Provider / Facility Postal Code Last Four",
                question_num: 9,
                question_suffix: 'L',
                key: "F[0].provider.postalCode_LastFourNumbers[#{PROVIDER_ITERATOR}]"
            }
          }
        }
      }.freeze

      def expand_va_file_number
        va_file_number = extract_va_file_number(@form_data['vaFileNumber'])
        ['', '1'].each do |suffix|
          @form_data["vaFileNumber#{suffix}"] = va_file_number
        end
      end

      def expand_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        ['', '1', '2', '3'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
        end
      end

      def expand_claimant_address
        @form_data['claimantAddress']['country'] = extract_country(@form_data['claimantAddress'])
        @form_data['claimantAddress']['postalCode'] = split_postal_code(@form_data['claimantAddress'])
      end

      def expand_veteran_full_name
        ['', '1'].each do |suffix|
          @form_data["veteranFullName#{suffix}"] = extract_middle_i(@form_data, 'veteranFullName')
        end
      end

      def expand_veteran_dob
        veteran_date_of_birth = @form_data['veteranDateOfBirth']
        ['', '1'].each do |suffix|
          @form_data["veteranDateOfBirth#{suffix}"] = split_date(veteran_date_of_birth)
        end
      end

      def expand_veteran_service_number
        veteran_service_number = @form_data['veteranServiceNumber']
        if veteran_service_number
          ['', '1'].each do |suffix|
            @form_data["veteranServiceNumber#{suffix}"] = veteran_service_number
          end
        end
      end

      def expand_providers(providers)
        return if providers.blank?
       
        providers.each do |provider|
          dates_of_treatment = provider['treatmentDateRange']
          date_ranges = {
            "dateRangeStart" => dates_of_treatment['from'],
            "dateRangeEnd" => dates_of_treatment['to']
          }
          provider['treatmentDateRange'] = date_ranges
          provider['street'] = provider['providerFacilityAddress']['street']
          provider['street2'] = provider['providerFacilityAddress']['street2']
          provider['city'] = provider['providerFacilityAddress']['city']
          provider['state'] = provider['providerFacilityAddress']['state']
          provider['country'] = extract_country(provider['providerFacilityAddress'])
          provider['postalCode'] = split_postal_code(provider['providerFacilityAddress'])
          # extras_address = combine_name_addr_extras(provider, 'providerFacilityName', 'providerFacilityAddress')
          # PdfFill::FormValue.new(provider['providerFacilityAddress'], extras_address)
        end
      end

      def merge_fields
        expand_va_file_number

        expand_ssn

        expand_veteran_full_name

        expand_signature(@form_data['veteranFullName'])

        @form_data['printedName'] = @form_data['signature']

        expand_claimant_address

        expand_veteran_dob

        expand_veteran_service_number

        @form_data['providerFacility'] = expand_providers(@form_data['providerFacility'])

        @form_data
      end
    end
  end
end
