# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va21p530 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      PLACE_OF_DEATH_KEY = {
        'vaMedicalCenter' => 'VA MEDICAL CENTER',
        'stateVeteransHome' => 'STATE VETERANS HOME',
        'nursingHome' => 'NURSING HOME UNDER VA CONTRACT'
      }.freeze

      # rubocop:disable Layout/LineLength
      KEY = {
        'burialAllowanceRequested' => {
          'checkbox' => {
            'nonService' => {
              key: 'form1[0].#subform[37].Non-Service-ConnectedDeath[0]'
            },
            'service' => {
              key: 'form1[0].#subform[37].Service-ConnectedDeath[0]'
            },
            'vaMC' => {
              key: 'form1[0].#subform[37].UnclaimedRemains[0]'
            }
          }
        },
        'signature' => {
          key: 'form1[0].#subform[37].CLAIMANT_SIGNATURE[0]',
          limit: 45,
          question_num: 20,
          question_text: 'SIGNATURE OF CLAIMANT',
          question_suffix: 'A'
        },
        'amountIncurred' => {
          key: 'form1[0].#subform[37].COST_OF_BURIAL[0]',
          question_num: 19,
          dollar: true,
          question_text: "EXPENSES INCURED FOR THE TRANSPORTATION OF THE VETERAN'S REMAINS FROM THE PLACE OF DEATH TO THE FINAL RESTING PLACE",
          limit: 12
        },
        'amountGovtContribution' => {
          key: 'form1[0].#subform[37].AMOUNT[0]',
          question_num: 18,
          question_suffix: 'B',
          dollar: true,
          question_text: 'AMOUNT OF GOVERNMENT OR EMPLOYER CONTRIBUTION',
          limit: 10
        },
        'placeOfRemains' => {
          key: 'form1[0].#subform[37].PLACE_OF_DEATH[1]',
          limit: 80,
          question_num: 16,
          question_text: "PLACE OF BURIAL OR LOCATION OF DECEASED VETERAN'S REMAINS"
        },
        'hasGovtContributions' => {
          key: 'form1[0].#subform[37].YES5[0]'
        },
        'noGovtContributions' => {
          key: 'form1[0].#subform[37].NO5[0]'
        },
        'hasStateCemetery' => {
          key: 'form1[0].#subform[37].YES4[2]'
        },
        'noStateCemetery' => {
          key: 'form1[0].#subform[37].NO4[2]'
        },
        'hasFederalCemetery' => {
          key: 'form1[0].#subform[37].YES4[0]'
        },
        'noFederalCemetery' => {
          key: 'form1[0].#subform[37].NO4[0]'
        },
        'hasBenefitsUnclaimedRemains' => {
          key: 'form1[0].#subform[37].YES4[4]'
        },
        'noBenefitsUnclaimedRemains' => {
          key: 'form1[0].#subform[37].NO4[4]'
        },
        'hasPlotAllowance' => {
          key: 'form1[0].#subform[37].YES4[1]'
        },
        'noPlotAllowance' => {
          key: 'form1[0].#subform[37].NO4[1]'
        },
        'officialPosition' => {
          key: 'officialPosition',
          limit: 48,
          question_num: 20,
          question_suffix: 'B',
          question_text: 'OFFICIAL POSITION OF PERSON SIGNING ON BEHALF OF FIRM, CORPORATION OR STATE AGENCY'
        },
        'hasBurialAllowance' => {
          key: 'form1[0].#subform[37].YES4[3]'
        },
        'noBurialAllowance' => {
          key: 'form1[0].#subform[37].NO4[3]'
        },
        'hasPreviouslyReceivedAllowance' => {
          key: 'form1[0].#subform[37].YES2[0]'
        },
        'noPreviouslyReceivedAllowance' => {
          key: 'form1[0].#subform[37].NO2[0]'
        },
        'locationOfDeath' => {
          'checkbox' => {
            'vaMedicalCenter' => {
              key: 'form1[0].#subform[37].CheckBox1[1]'
            },
            'stateVeteransHome' => {
              key: 'form1[0].#subform[37].CheckBox2[1]'
            },
            'nursingHome' => {
              key: 'form1[0].#subform[37].CheckBox3[1]'
            },
            'other' => {
              key: 'form1[0].#subform[37].CheckBox4[1]'
            }
          },
          'other' => {
            key: 'form1[0].#subform[37].OTHER_SPECIFY[1]',
            question_num: 13,
            question_suffix: 'B',
            question_text: "WHERE DID THE VETERAN'S DEATH OCCUR?",
            limit: 50
          }
        },
        'burialCost' => {
          key: 'form1[0].#subform[37].COST_OF_BURIAL[1]',
          limit: 12,
          question_num: 13,
          question_suffix: 'A',
          question_text: 'If VA Medical Center Death is checked, provide actual burial cost'
        },
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[36].VeteransFirstName[0]',
            limit: 12,
            question_num: 1,
            question_text: "DECEASED VETERAN'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[36].VeteransMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[36].VeteransLastName[0]',
            limit: 18,
            question_num: 1,
            question_text: "DECEASED VETERAN'S LAST NAME"
          }
        },
        'previousNames' => {
          key: 'form1[0].#subform[36].OTHER_NAME[0]',
          question_num: 12,
          question_text: 'IF VETERAN SERVED UNDER NAME OTHER THAN THAT SHOWN IN ITEM 1, GIVE FULL NAME AND SERVICE RENDERED UNDER THAT NAME',
          limit: 180
        },
        'burialDate' => {
          key: 'form1[0].#subform[36].DATE_OF_BURIAL[0]',
          format: 'date'
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[36].VAFileNumber[0]'
        },
        'placeOfDeath' => {
          key: 'form1[0].#subform[36].PLACE_OF_DEATH[0]',
          limit: 52,
          question_num: 10,
          question_suffix: 'B',
          question_text: 'PLACE OF DEATH'
        },
        'claimantEmail' => {
          key: 'form1[0].#subform[36].PreferredE_MailAddress[0]',
          limit: 31,
          question_num: 7,
          question_text: 'PREFERRED E-MAIL ADDRESS'
        },
        'claimantFullName' => {
          'first' => {
            key: 'form1[0].#subform[36].ClaimantsFirstName[0]',
            limit: 12,
            question_num: 4,
            question_text: "CLAIMANT'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[36].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[36].ClaimantsLastName[0]',
            limit: 18,
            question_num: 4,
            question_text: "CLAIMANT'S LAST NAME"
          }
        },
        'claimantAddress' => {
          'street' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 5,
            question_text: "CLAIMANT'S ADDRESS - STREET"
          },
          'street2' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 5,
            question_text: "CLAIMANT'S ADDRESS - APT/UNIT NO."
          },
          'city' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_City[0]',
            limit: 18,
            question_num: 5,
            question_text: "CLAIMANT'S ADDRESS - CITY"
          },
          'state' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_StateOrProvince[0]',
            limit: 2,
            question_num: 5,
            question_text: "CLAIMANT'S ADDRESS - STATE"
          },
          'country' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_Country[0]',
            limit: 2,
            question_num: 5,
            question_text: "CLAIMANT'S ADDRESS - COUNTRY"
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[36].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]',
              limit: 5,
              question_num: 5,
              question_text: "CLAIMANT'S ADDRESS - POSTAL CODE - FIRST FIVE"
            },
            'lastFour' => {
              key: 'form1[0].#subform[36].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]',
              limit: 4,
              question: 5,
              question_text: "CLAIMANT's ADDRESS - POSTAL CODE - LAST FOUR"
            }
          }
        },
        'relationship' => {
          'checkbox' => {
            'spouse' => {
              key: 'form1[0].#subform[36].CheckBox1[0]'
            },
            'child' => {
              key: 'form1[0].#subform[36].CheckBox2[0]'
            },
            'executor' => {
              key: 'form1[0].#subform[36].CheckBox4[0]'
            },
            'other' => {
              key: 'form1[0].#subform[36].CheckBox5[0]'
            },
            'parent' => {
              key: 'form1[0].#subform[36].CheckBox3[0]'
            }
          },
          'other' => {
            limit: 58,
            question_num: 8,
            question_text: 'RELATIONSHIP OF CLAIMANT TO DECEASED VETERAN',
            key: 'form1[0].#subform[36].OTHER_SPECIFY[0]'
          }
        },
        'toursOfDuty' => {
          limit: 3,
          first_key: 'rank',
          'dateRangeStart' => {
            key: "toursOfDuty.dateRangeStart[#{ITERATOR}]",
            question_num: 11,
            question_suffix: 'A',
            question_text: 'ENTERED SERVICE (date)',
            format: 'date'
          },
          'placeOfEntry' => {
            key: "toursOfDuty.placeOfEntry[#{ITERATOR}]",
            limit: 14,
            question_num: 11,
            question_suffix: 'A',
            question_text: 'ENTERED SERVICE (place)'
          },
          'serviceNumber' => {
            key: "toursOfDuty.serviceNumber[#{ITERATOR}]",
            limit: 12,
            question_num: 11,
            question_suffix: 'B',
            question_text: 'SERVICE NUMBER'
          },
          'dateRangeEnd' => {
            key: "toursOfDuty.dateRangeEnd[#{ITERATOR}]",
            question_num: 11,
            question_suffix: 'C',
            question_text: 'SEPARATED FROM SERVICE (date)',
            format: 'date'
          },
          'placeOfSeparation' => {
            key: "toursOfDuty.placeOfSeparation[#{ITERATOR}]",
            question_num: 11,
            question_suffix: 'C',
            question_text: 'SEPARATED FROM SERVICE (place)',
            limit: 15
          },
          'rank' => {
            key: "toursOfDuty.rank[#{ITERATOR}]",
            question_num: 11,
            question_suffix: 'D',
            question_text: 'GRADE, RANK OR RATING, ORGANIZATION AND BRANCH OF SERVICE',
            limit: 31
          }
        },
        'placeOfBirth' => {
          key: 'form1[0].#subform[36].PLACE_OF_BIRTH[0]',
          limit: 71,
          question_num: 9,
          question_suffix: 'B',
          question_text: 'PLACE OF BIRTH'
        },
        'veteranDateOfBirth' => {
          key: 'form1[0].#subform[36].DATE_OF_BIRTH[0]',
          format: 'date'
        },
        'deathDate' => {
          key: 'form1[0].#subform[36].DATE_OF_DEATH[0]',
          format: 'date'
        },
        'claimantPhone' => {
          'first' => {
            key: 'form1[0].#subform[36].PreferredTelephoneNumber_AreaCode[0]'
          },
          'second' => {
            key: 'form1[0].#subform[36].PreferredTelephoneNumber_FirstThreeNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[36].PreferredTelephoneNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'form1[0].#subform[37].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[37].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[37].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        'firmNameAndAddr' => {
          key: 'form1[0].#subform[37].FULL_NAME[0]',
          limit: 90,
          question_num: 21,
          question_text: 'FULL NAME AND ADDRESS OF THE FIRM, CORPORATION, OR STATE AGENCY FILING AS CLAIMANT'
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        }
      }.freeze
      # rubocop:enable Layout/LineLength

      def split_phone(hash, key)
        phone = hash[key]
        return if phone.blank?

        hash[key] = {
          'first' => phone[0..2],
          'second' => phone[3..5],
          'third' => phone[6..9]
        }
      end

      def split_postal_code(hash)
        postal_code = hash['claimantAddress']['postalCode']
        return if postal_code.blank?

        hash['claimantAddress']['postalCode'] = {
          'firstFive' => postal_code[0..4],
          'lastFour' => postal_code[6..10]
        }
      end

      def expand_checkbox_in_place(hash, key)
        hash.merge!(expand_checkbox(hash[key], StringHelpers.capitalize_only(key)))
      end

      def expand_relationship(hash, key)
        expand_checkbox_as_hash(hash[key], 'type')
      end

      def expand_tours_of_duty(tours_of_duty)
        return if tours_of_duty.blank?

        tours_of_duty.each do |tour_of_duty|
          expand_date_range(tour_of_duty, 'dateRange')
          tour_of_duty['rank'] = combine_hash(tour_of_duty, %w[serviceBranch rank], ', ')
        end
      end

      def expand_place_of_death
        location_of_death = @form_data['locationOfDeath']
        return if location_of_death.blank?

        location = location_of_death['location']

        @form_data['placeOfDeath'] =
          if location == 'other'
            location_of_death['other']
          else
            PLACE_OF_DEATH_KEY[location]
          end
      end

      def expand_firm
        if @form_data['relationship'].try(:[], 'isEntity')
          combine_name_addr(
            @form_data,
            name_key: 'firmName',
            address_key: 'claimantAddress',
            combined_key: 'firmNameAndAddr'
          )
        end
      end

      def expand_burial_allowance
        burial_allowance = @form_data['burialAllowanceRequested']
        return if burial_allowance.blank?

        @form_data['burialAllowanceRequested'] = {
          'value' => burial_allowance
        }

        expand_checkbox_as_hash(@form_data['burialAllowanceRequested'], 'value')
      end

      # VA file number can be up to 10 digits long; An optional leading 'c' or 'C' followed by
      # 7-9 digits. The file number field on the 4142 form has space for 9 characters so trim the
      # potential leading 'c' to ensure the file number will fit into the form without overflow.
      def extract_va_file_number(va_file_number)
        return va_file_number if va_file_number.blank? || va_file_number.length < 10

        va_file_number.sub(/^[Cc]/, '')
      end

      # rubocop:disable Metrics/MethodLength
      def merge_fields(_options = {})
        expand_signature(@form_data['claimantFullName'])

        %w[veteranFullName claimantFullName].each do |attr|
          extract_middle_i(@form_data, attr)
        end

        ssn = @form_data['veteranSocialSecurityNumber']
        ['', '2'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
        end

        split_phone(@form_data, 'claimantPhone')

        split_postal_code(@form_data)

        expand_relationship(@form_data, 'relationship')

        expand_place_of_death

        expand_tours_of_duty(@form_data['toursOfDuty'])

        @form_data['previousNames'] = combine_previous_names(@form_data['previousNames'])

        @form_data['vaFileNumber'] = extract_va_file_number(@form_data['vaFileNumber'])

        expand_burial_allowance

        expand_firm

        expand_checkbox_as_hash(@form_data['locationOfDeath'], 'location')

        %w[
          previouslyReceivedAllowance
          burialAllowance
          plotAllowance
          benefitsUnclaimedRemains
          federalCemetery
          stateCemetery
          govtContributions
        ].each do |attr|
          expand_checkbox_in_place(@form_data, attr)
        end

        @form_data
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
# rubocop:enable Metrics/ClassLength
