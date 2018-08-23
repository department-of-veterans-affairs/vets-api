# frozen_string_literal: true

require 'pdf_fill/forms/form_helper'

module PdfFill
  module Forms
    class Va214142 < FormBase
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
        'providers' => {
          limit: 5,
          first_key: 'providerOrFacilityName',
          question_text: 'PROVIDERS',
                      
          'providerName' => {
            key: "F[0].provider.name[#{PROVIDER_ITERATOR}]"
          },
          'datesOfTreatment' => {
            question_text: 'DATES OF TREATMENT AT THIS PROVIDER',
            limit: 2,
            'dateRangeStart' => {
              key: "F[#{PROVIDER_ITERATOR}].provider.datesOfTreatment.fromDate[0]"
            },
            'dateRangeEnd' => {
              key: "F#{PROVIDER_ITERATOR}].provider.datesOfTreatment.toDate[0]"
            },
            'dateRangeStart1' => {
              key: "F[#{PROVIDER_ITERATOR}].provider.datesOfTreatment.fromDate[1]"
            },
            'dateRangeEnd1' => {
              key: "F[#{PROVIDER_ITERATOR}].provider.datesOfTreatment.toDate[1]"
            }
          },
          'numberAndStreet' => {
            limit: 30,
            key: "F[0].provider.numberAndStreet[#{PROVIDER_ITERATOR}]"
          },
          'apartmentOrUnitNumber' => {
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
            key:"F[0].provider.country[#{PROVIDER_ITERATOR}]"
          },
          'postalCode' => {
            'firstFive' => {
              key: "F[0].provider.postalCode_FirstFiveNumbers[#{PROVIDER_ITERATOR}]"
            },
            'lastFour' => {
              key: "F[0].provider.postalCode_LastFourNumbers[#{PROVIDER_ITERATOR}]"
            } 
          }
        }
      }.freeze

      def expand_providers(providers)
        return if providers.blank?

        providers.each do |provider|
          provider['postalCode'] = FormHelper.split_postal_code(provider)
          dates_of_treatment = provider['datesOfTreatment']
          date_ranges = []
          dates_of_treatment.each_with_index do |date_of_treatment, index|
            date_ranges[index] = {
              "dateRangeStart#{index}" => date_of_treatment['fromDate'],
              "dateRangeEnd#{index}" => date_of_treatment['toDate']
            }
          end
          provider['datesOfTreatment'] = date_ranges
        end
      end

      def merge_fields

        va_file_number = FormHelper.extract_va_file_number(@form_data['vaFileNumber'])
        ['', '1'].each do |suffix|
          @form_data["vaFileNumber#{suffix}"] = va_file_number
        end
        
        ssn = @form_data['veteranSocialSecurityNumber']
        ['', '1', '2', '3'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = FormHelper.split_ssn(ssn)
        end

        ['', '1'].each do |suffix|
          @form_data["veteranFullName#{suffix}"] = FormHelper.extract_middle_i(@form_data, 'veteranFullName')
        end

        expand_signature(@form_data['veteranFullName'])

        @form_data['printedName'] = @form_data['signature']

        @form_data['claimantAddress']['country'] = FormHelper.extract_country(@form_data['claimantAddress'])

        @form_data['claimantAddress']['postalCode'] = FormHelper.split_postal_code(@form_data['claimantAddress'])

        veteran_date_of_birth = @form_data['veteranDateOfBirth']
        ['', '1'].each do |suffix|
          @form_data["veteranDateOfBirth#{suffix}"] = FormHelper.split_date(veteran_date_of_birth)
        end

        veteran_service_number = @form_data['veteranServiceNumber']
        if veteran_service_number
          ['', '1'].each do |suffix|
            @form_data["veteranServiceNumber#{suffix}"] =  veteran_service_number
          end
        end

        @form_data['providers'] = expand_providers(@form_data['providers'])

        @form_data
      end
    end
  end
end
