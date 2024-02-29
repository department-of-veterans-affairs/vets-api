# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va21p530ez < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      PLACE_OF_DEATH_KEY = {
        'vaMedicalCenter' => 'VA MEDICAL CENTER',
        'stateVeteransHome' => 'STATE VETERANS HOME',
        'nursingHome' => 'NURSING HOME UNDER VA CONTRACT'
      }.freeze

      # rubocop:disable Layout/LineLength
      KEY = {
        'veteranFullName' => { # start veteran information
          'first' => {
            key: 'form1[0].#subform[82].VeteransFirstName[0]',
            limit: 12,
            question_num: 1,
            question_text: "DECEASED VETERAN'S FIRST NAME"
          },
          'middle' => {
            key: 'form1[0].#subform[82].VeteransMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[82].VeteransLastName[0]',
            limit: 18,
            question_num: 1,
            question_text: "DECEASED VETERAN'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[82].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[82].VAFileNumber[0]',
          question_num: 3,
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[82].Veterans_DOBmonth[0]',
            limit: 2,
            question_num: 4,
            question_suffix: 'A',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BIRTH (MM-DD-YYYY)'
          },
          'day' => {
            key: 'form1[0].#subform[82].Veterans_DOBday[0]',
            limit: 2,
            question_num: 4,
            question_suffix: 'B',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BIRTH (MM-DD-YYYY)'
          },
          'year' => {
            key: 'form1[0].#subform[82].Veterans_DOByear[0]',
            limit: 4,
            question_num: 4,
            question_suffix: 'C',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BIRTH (MM-DD-YYYY)'
          }
        },
        'deathDate' => {
          'month' => {
            key: 'form1[0].#subform[82].Veterans_DateOfDeathmonth[0]',
            limit: 2,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF DEATH (MM-DD-YYYY)'
          },
          'day' => {
            key: 'form1[0].#subform[82].Veterans_DateofDeathday[0]',
            limit: 2,
            question_num: 5,
            question_suffix: 'B',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF DEATH (MM-DD-YYYY)'
          },
          'year' => {
            key: 'form1[0].#subform[82].Veterans_DateofDeathyear[0]',
            limit: 4,
            question_num: 5,
            question_suffix: 'C',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF DEATH (MM-DD-YYYY)'
          }
        },
        'burialDate' => {
          'month' => {
            key: 'form1[0].#subform[82].Veterans_Date_of_Burial_Month[0]',
            limit: 2,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BURIAL (MM-DD-YYYY)'
          },
          'day' => {
            key: 'form1[0].#subform[82].Veterans_Date_of_Burial_Day[0]',
            limit: 2,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BURIAL  (MM-DD-YYYY)'
          },
          'year' => {
            key: 'form1[0].#subform[82].Veterans_Date_of_Burial_Year[0]',
            limit: 4,
            question_num: 6,
            question_suffix: 'C',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BURIAL (MM-DD-YYYY)'
          }
        }, #end veteran information
        'claimantFullName' => { #start claimant information
          'first' => {
            key: 'form1[0].#subform[82].ClaimantsFirstName[0]',
            limit: 12,
            question_num: 7,
            question_text: "CLAIMANT'S FIRST NAME"
          },
          'middle' => {
            key: 'form1[0].#subform[82].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[82].ClaimantsLastName[0]',
            limit: 18,
            question_num: 7,
            question_text: "CLAIMANT'S LAST NAME"
          }
        },
        'claimantSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[82].Claimants_SocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[82].Claimants_SocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[82].Claimants_SocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'claimantDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[82].Claimants_DOBmonth[0]',
            limit: 2,
            question_num: 9,
            question_suffix: 'A',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > CLAIMANT\'S DATE OF BIRTH (MM-DD-YYYY)'
          },
          'day' => {
            key: 'form1[0].#subform[82].Claimants_DOBday[0]',
            limit: 2,
            question_num: 9,
            question_suffix: 'B',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > CLAIMANT\'S DATE OF BIRTH (MM-DD-YYYY)'
          },
          'year' => {
            key: 'form1[0].#subform[82].Claimants_DOByear[0]',
            limit: 4,
            question_num: 9,
            question_suffix: 'C',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > CLAIMANT\'S DATE OF BIRTH (MM-DD-YYYY)'
          }
        },
        'claimantAddress' => {
          'street' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 10,
            question_text: "CLAIMANT'S ADDRESS - STREET"
          },
          'street2' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 10,
            question_text: "CLAIMANT'S ADDRESS - APT/UNIT NO."
          },
          'city' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_City[0]',
            limit: 18,
            question_num: 10,
            question_text: "CLAIMANT'S ADDRESS - CITY"
          },
          'state' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_StateOrProvince[0]',
            limit: 2,
            question_num: 10,
            question_text: "CLAIMANT'S ADDRESS - STATE"
          },
          'country' => {
            key: 'form1[0].#subform[82].CurrentMailingAddress_Country[0]',
            limit: 2,
            question_num: 10,
            question_text: "CLAIMANT'S ADDRESS - COUNTRY"
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[82].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]',
              limit: 5,
              question_num: 10,
              question_text: "CLAIMANT'S ADDRESS - POSTAL CODE - FIRST FIVE"
            },
            'lastFour' => {
              key: 'form1[0].#subform[82].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]',
              limit: 4,
              question: 10,
              question_text: "CLAIMANT's ADDRESS - POSTAL CODE - LAST FOUR"
            }
          }
        },
        'claimantPhone' => {
          'first' => {
            key: 'form1[0].#subform[82].TelephoneNumber_AreaCode[0]'
          },
          'second' => {
            key: 'form1[0].#subform[82].TelephoneNumber_FirstThreeNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[82].TelephoneNumber_LastFourNumbers[0]'
          }
        },
        'claimantEmail' => {
          key: 'form1[0].#subform[82].E-Mail_Address[0]',
          limit: 31,
          question_num: 12,
          question_text: 'E-MAIL ADDRESS'
        },
        'relationshipToVeteran' => {
          'checkbox' => {
            'spouse' => {
              key: 'form1[0].#subform[82].CheckboxSpouse[0]'
            },
            'child' => {
              key: 'form1[0].#subform[82].CheckboxChild[0]'
            },
            'parent' => {
              key: 'form1[0].#subform[82].CheckboxParent[0]'
            },
            'executor' => {
              key: 'form1[0].#subform[82].CheckboxExecutor[0]'
            },
            'funeralHome' => {
              key: 'form1[0].#subform[82].CheckboxFuneralHome[0]'
            },
            'other' => {
              key: 'form1[0].#subform[82].CheckboxOther[0]'
            },
          }
        },
        'toursOfDuty' => { #might need to break into three individual ones
          limit: 3,
          first_key: 'rank',
          'dateRangeStart' => {
            key: "form1[0].#subform[82].DATE_ENTERED_SERVICE[#{ITERATOR}]",
            question_num: 14,
            question_suffix: 'A',
            question_text: 'ENTERED SERVICE (date)',
            format: 'date'
          },
          'placeOfEntry' => {
            key: "form1[0].#subform[82].PLACE[#{ITERATOR}]",
            limit: 14,
            question_num: 14,
            question_suffix: 'A',
            question_text: 'ENTERED SERVICE (place)'
          },
          'serviceNumber' => {
            key: "form1[0].#subform[82].SERVICE_NUMBER[#{ITERATOR}]",
            limit: 12,
            question_num: 14,
            question_suffix: 'B',
            question_text: 'SERVICE NUMBER'
          },
          'dateRangeEnd' => {
            key: "form1[0].#subform[82].DATE_SEPARATED_SERVICE[#{ITERATOR}]",
            question_num: 14,
            question_suffix: 'C',
            question_text: 'SEPARATED FROM SERVICE (date)',
            format: 'date'
          },
          'placeOfSeparation' => {
            key: "form1[0].#subform[82].PLACE_SEPARATED[#{ITERATOR}]",
            question_num: 14,
            question_suffix: 'C',
            question_text: 'SEPARATED FROM SERVICE (place)',
            limit: 15
          },
          'rank' => {
            key: "form1[0].#subform[82].GRADE_RANK_OR_RATING[#{ITERATOR}]",
            question_num: 11,
            question_suffix: 'D',
            question_text: 'GRADE, RANK OR RATING, ORGANIZATION AND BRANCH OF SERVICE',
            limit: 31
          }
        },
        'previousNames' => {
          key: 'form1[0].#subform[82].OTHER_NAME_VETERAN_SERVED_UNDER[0]',
          question_num: 15,
          question_text: 'IF VETERAN SERVED UNDER NAME OTHER THAN THAT SHOWN IN ITEM 1, GIVE FULL NAME AND SERVICE RENDERED UNDER THAT NAME',
          limit: 180
        },
        'veteranSocialSecurityNumberPageTwo' => {
          'first' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        'finalRestingPlace' => { #break into yes/nos
          'checkbox' => {
            'cemetery' => {
              key: 'form1[0].#subform[83].#subform[84].RestingPlaceCemetery[5]'
            },
            'privateResidence' => {
              key: 'form1[0].#subform[83].#subform[84].RestingPlacePrivateResidence[5]'
            },
            'mausoleum' => {
              key: 'form1[0].#subform[83].#subform[84].RestingPlaceMausoleum[5]'
            },
            'other' => {
              key: 'form1[0].#subform[83].#subform[84].RestingPlaceOther[5]'
            },
          },
          'other' => {
            limit: 58,
            question_num: 16,
            question_text: "PLACE OF BURIAL PLOT, INTERMENT SITE, OR FINAL RESTING PLACE OF DECEASED VETERAN'S REMAINS",
            key: 'form1[0].#subform[83].#subform[84].PLACE_OF_DEATH[0]'
          }
        },
        'yesFederalCemetery' => {
          key: 'form1[0].#subform[37].FederalCemeteryYES[0]'
        },
        'noFederalCemetery' => {
          key: 'form1[0].#subform[37].FederalCemeteryNO[0]'
        },
        'federalCemeteryName' => {
          key: 'form1[0].#subform[37].FederalCemeteryName[0]'
        },
        'hasStateCemetery' => {
          key: 'form1[0].#subform[37].HasStateCemetery[2]'
        },
        'hasTribalTrust' => {
          key: 'form1[0].#subform[37].HasTribalTrust[2]'
        },
        'noStateCemetery' => {
          key: 'form1[0].#subform[37].NoStateCemetery[2]'
        },
        'stateCemeteryOrTribalTrustName' => {
          key: 'form1[0].#subform[37].StateCemeteryOrTribalTrustName[2]'
        },
        'stateCemeteryOrTribalTrustZip' => {
          key: 'form1[0].#subform[37].StateCemeteryOrTribalTrustZip[2]'
        },
        'yesGovtContributions' => {
          key: 'form1[0].#subform[37].GovContributionYES[0]'
        },
        'noGovtContributions' => {
          key: 'form1[0].#subform[37].GovContributionNO[0]'
        },
        'amountGovtContributionFirst' => {
          key: 'form1[0].#subform[37].FirstAmount[0]',
          question_num: 19,
          question_suffix: 'B',
          dollar: true,
          question_text: 'AMOUNT OF GOVERNMENT OR EMPLOYER CONTRIBUTION',
          limit: 2
        },
        'amountGovtContributionSecond' => {
          key: 'form1[0].#subform[37].SecondAmount[0]',
          question_num: 19,
          question_suffix: 'B',
          dollar: true,
          question_text: 'AMOUNT OF GOVERNMENT OR EMPLOYER CONTRIBUTION',
          limit: 3
        },
        'amountGovtContributionThird' => {
          key: 'form1[0].#subform[37].ThirdAmount[0]',
          question_num: 19,
          question_suffix: 'B',
          dollar: true,
          question_text: 'AMOUNT OF GOVERNMENT OR EMPLOYER CONTRIBUTION',
          limit: 2
        },
        'burialAllowanceRequested' => {
          'checkbox' => {
            'nonService' => {
              key: 'form1[0].#subform[83].Non-Service-Connected[0]'
            },
            'service' => {
              key: 'form1[0].#subform[83].Service-Connected[0]'
            },
            'unclaimed' => {
              key: 'form1[0].#subform[83].UnclaimedRemains[0]'
            }
          }
        },
        'locationOfDeath' => {
          'checkbox' => {
            'nursingHomeUnpaid' => {
              key: 'form1[0].#subform[83].NursingHomeOrResidenceNotPaid[1]'
            },
            'nursingHomePaid' => {
              key: 'form1[0].#subform[83].NursingHomeOrResidencePaid[1]'
            },
            'vaMedicalCenter' => {
              key: 'form1[0].#subform[83].VaMedicalCenter[1]'
            },
            'atHome' => {
              key: 'form1[0].#subform[83].StateVeteransHome[1]'
            },
            'other' => {
              key: 'form1[0].#subform[83].DeathOccurredOther[1]'
            }
          },
          'other' => {
            key: 'form1[0].#subform[37].DeathOccurredOtherSpecify[1]',
            question_num: 20,
            question_suffix: 'B',
            question_text: "WHERE DID THE VETERAN'S DEATH OCCUR?",
            limit: 50
          }
        },
        'yesPreviouslyReceivedAllowance' => {
          key: 'form1[0].#subform[83].PreviousAllowanceYes[0]'
        },
        'noPreviouslyReceivedAllowance' => {
          key: 'form1[0].#subform[83].PreviousAllowanceNo[0]'
        },
        'yesBurialExpenseResponsibility' => {
          key: 'form1[0].#subform[83].ResponsibleForBurialCostYes[0]'
        },
        'noBurialExpenseResponsibility' => {
          key: 'form1[0].#subform[83].ResponsibleForBurialCostNo[0]'
        },
        'certifyUnclaimedAndNotSufficientResourcesYes' => {
          key: 'form1[0].#subform[83].certifyUnclaimedYes[0]'
        },
        'certifyUnclaimedAndNotSufficientResourcesNo' => {
          key: 'form1[0].#subform[83].certifyUnclaimedNo[0]'
        },
        'yesPlotExpenseResponsibility' => {
          key: 'form1[0].#subform[83].ResponsibleForPlotIntermentCostYes[0]'
        },
        'noPlotExpenseResponsibility' => {
          key: 'form1[0].#subform[83].ResponsibleForPlotIntermentCostNo[0]'
        },
        'yesTransportationExpenses' => {
          key: 'form1[0].#subform[83].ResponsibleForTransportationYes[0]'
        },
        'noTransportationExpenses' => {
          key: 'form1[0].#subform[83].ResponsibleForTransportationNo[0]'
        },
        'wantClaimFDCProcessedYes' => {
          key: 'form1[0].#subform[83].WantClaimFDCProcessedYes[0]'
        },
        'wantClaimFDCProcessedNo' => {
          key: 'form1[0].#subform[83].WantClaimFDCProcessedNo[0]'
        },
        'claimantSignature' => {
          key: 'form1[0].#subform[83].CLAIMANT_SIGNATURE[0]',
          limit: 45,
          question_num: 25,
          question_text: 'SIGNATURE OF CLAIMANT',
          question_suffix: 'A'
        },
        'claimantPrintedName' => {
          key: 'form1[0].#subform[83].ClaimantPrintedName[0]',
          limit: 45,
          question_num: 25,
          question_text: 'Printed Name of Claimant',
          question_suffix: 'B'
        },
        'firmNameAndAddr' => {
          key: 'form1[0].#subform[83].FirmNameAndAddress[0]',
          limit: 90,
          question_num: 26,
          question_suffix: 'B',
          question_text: 'FULL NAME AND ADDRESS OF THE FIRM, CORPORATION, OR STATE AGENCY FILING AS CLAIMANT'
        },
        'officialPosition' => {
          key: 'form1[0].#subform[83].OfficialPosition[0]',
          limit: 90,
          question_num: 26,
          question_suffix: 'B',
          question_text: 'OFFICIAL POSITION OF PERSON SIGNING ON BEHALF OF FIRM, CORPORATION OR STATE AGENCY'
        },
        'veteranSocialSecurityNumberPageThree' => {
          'first' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_FirstThreeNumbers[2]'
          },
          'second' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_SecondTwoNumbers[2]'
          },
          'third' => {
            key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_LastFourNumbers[2]'
          }
        },
        
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
        if @form_data['relationshipToVeteran'].try(:[], 'isEntity')
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

        expand_relationship(@form_data, 'relationshipToVeteran')

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
