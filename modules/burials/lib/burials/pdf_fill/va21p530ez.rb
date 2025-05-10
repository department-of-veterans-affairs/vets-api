# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

# rubocop:disable Metrics/ClassLength
module Burials
  module PdfFill
    # Forms module
    module Forms
      # Burial 21P-530EZ PDF Filler class
      class Va21p530ez < ::PdfFill::Forms::FormBase
        include ::PdfFill::Forms::FormHelper

        # The ID of the form being processed
        FORM_ID = '21P-530EZ'

        # An external iterator used in data processing
        ITERATOR = ::PdfFill::HashConverter::ITERATOR

        # The path to the PDF template for the form
        TEMPLATE = Burials::PDF_PATH

        # A mapping of care facilities to their labels
        PLACE_OF_DEATH_KEY = {
          'vaMedicalCenter' => 'VA MEDICAL CENTER',
          'stateVeteransHome' => 'STATE VETERANS HOME',
          'nursingHome' => 'NURSING HOME UNDER VA CONTRACT'
        }.freeze

        # Mapping of the filled out form into JSON
        # rubocop:disable Layout/LineLength
        KEY = {
          'veteranFullName' => { # start veteran information
            'first' => {
              key: 'form1[0].#subform[82].VeteransFirstName[0]',
              limit: 12,
              question_num: 1,
              question_text: "DECEASED VETERAN'S FIRST NAME"
            },
            'middleInitial' => {
              key: 'form1[0].#subform[82].VeteransMiddleInitial1[0]',
              question_num: 1,
              limit: 1,
              question_text: "DECEASED VETERAN'S MIDDLE INITIAL"
            },
            'last' => {
              key: 'form1[0].#subform[82].VeteransLastName[0]',
              limit: 18,
              question_num: 1,
              question_text: "DECEASED VETERAN'S LAST NAME"
            },
            'suffix' => {
              key: 'form1[0].#subform[82].Suffix[0]',
              question_num: 1,
              limit: 0,
              question_text: "DECEASED VETERAN'S SUFFIX"
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
            question_num: 3
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
          }, # end veteran information
          'claimantFullName' => { # start claimant information
            'first' => {
              key: 'form1[0].#subform[82].ClaimantsFirstName[0]',
              limit: 12,
              question_num: 7,
              question_text: "CLAIMANT'S FIRST NAME"
            },
            'middleInitial' => {
              key: 'form1[0].#subform[82].ClaimantsMiddleInitial1[0]'
            },
            'last' => {
              key: 'form1[0].#subform[82].ClaimantsLastName[0]',
              limit: 18,
              question_num: 7,
              question_text: "CLAIMANT'S LAST NAME"
            },
            'suffix' => {
              key: 'form1[0].#subform[82].ClaimantSuffix[0]',
              question_num: 7,
              limit: 0,
              question_text: "CLAIMANT'S SUFFIX"
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
          'claimantIntPhone' => {
            key: 'form1[0].#subform[82].IntTelephoneNumber[0]',
            question_num: 11,
            question_text: "CLAIMANT'S INTERNATIONAL PHONE NUMBER",
            limit: 0 # this will force this value that is not on the pdf to appear in the overflow
          },
          'claimantEmail' => {
            key: 'form1[0].#subform[82].E-Mail_Address[0]',
            limit: 31,
            question_num: 12,
            question_text: 'E-MAIL ADDRESS'
          },
          'relationshipToVeteran' => {
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
            'funeralDirector' => {
              key: 'form1[0].#subform[82].CheckboxFuneralHome[0]'
            },
            'otherFamily' => {
              key: 'form1[0].#subform[82].CheckboxOther[0]'
            }
          },
          'toursOfDuty' => {
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
            'militaryServiceNumber' => {
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
              question_num: 14,
              question_suffix: 'D',
              question_text: 'GRADE, RANK OR RATING, ORGANIZATION AND BRANCH OF SERVICE',
              limit: 31
            },
            'unit' => {
              key: "form1[0].#subform[82].GRADE_RANK_OR_RATING_UNIT[#{ITERATOR}]",
              question_num: 14,
              question_suffix: 'D',
              question_text: 'UNIT',
              limit: 0
            }
          },
          'previousNames' => {
            key: 'form1[0].#subform[82].OTHER_NAME_VETERAN_SERVED_UNDER[0]',
            question_num: 15,
            question_text: 'IF VETERAN SERVED UNDER NAME OTHER THAN THAT SHOWN IN ITEM 1, GIVE FULL NAME AND SERVICE RENDERED UNDER THAT NAME',
            limit: 180
          },
          'veteranSocialSecurityNumber2' => {
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
          'finalRestingPlace' => { # break into yes/nos
            'location' => {
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
              }
            },
            'other' => {
              limit: 58,
              question_num: 16,
              question_text: "PLACE OF BURIAL PLOT, INTERMENT SITE, OR FINAL RESTING PLACE OF DECEASED VETERAN'S REMAINS",
              key: 'form1[0].#subform[83].#subform[84].PLACE_OF_DEATH[0]'
            }
          },
          'hasNationalOrFederal' => {
            key: 'form1[0].#subform[37].FederalCemeteryYES[0]'
          },
          'noNationalOrFederal' => {
            key: 'form1[0].#subform[37].FederalCemeteryNo[0]'
          },
          'name' => {
            key: 'form1[0].#subform[37].FederalCemeteryName[0]',
            limit: 50
          },
          'cemetaryLocationQuestionCemetery' => {
            key: 'form1[0].#subform[37].HasStateCemetery[2]'
          },
          'cemetaryLocationQuestionTribal' => {
            key: 'form1[0].#subform[37].HasTribalTrust[2]'
          },
          'cemetaryLocationQuestionNone' => {
            key: 'form1[0].#subform[37].NoStateCemetery[2]'
          },
          'stateCemeteryOrTribalTrustName' => {
            key: 'form1[0].#subform[37].StateCemeteryOrTribalTrustName[2]',
            limit: 33
          },
          'stateCemeteryOrTribalTrustZip' => {
            key: 'form1[0].#subform[37].StateCemeteryOrTribalTrustZip[2]'
          },
          'hasGovtContributions' => {
            key: 'form1[0].#subform[37].GovContributionYES[0]'
          },
          'noGovtContributions' => {
            key: 'form1[0].#subform[37].GovContributionNo[0]'
          },
          'amountGovtContribution' => {
            key: 'form1[0].#subform[37].AmountGovtContribution[0]',
            question_num: 19,
            question_suffix: 'B',
            dollar: true,
            question_text: 'AMOUNT OF GOVERNMENT OR EMPLOYER CONTRIBUTION',
            limit: 5
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
              'stateVeteransHome' => {
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
              limit: 32
            },
            'placeAndLocation' => {
              limit: 42,
              question_num: 20,
              question_suffix: 'B',
              question_text: "PLEASE PROVIDE VETERAN'S SPECIFIC PLACE OF DEATH INCLUDING THE NAME AND LOCATION OF THE NURSING HOME, VA MEDICAL CENTER OR STATE VETERAN FACILITY.",
              key: 'form1[0].#subform[37].DeathOccurredPlaceAndLocation[1]'
            }
          },
          'hasPreviouslyReceivedAllowance' => {
            key: 'form1[0].#subform[83].PreviousAllowanceYes[0]'
          },
          'noPreviouslyReceivedAllowance' => {
            key: 'form1[0].#subform[83].PreviousAllowanceNo[0]'
          },
          'hasBurialExpenseResponsibility' => {
            key: 'form1[0].#subform[83].ResponsibleForBurialCostYes[0]'
          },
          'noBurialExpenseResponsibility' => {
            key: 'form1[0].#subform[83].ResponsibleForBurialCostNo[0]'
          },
          'hasConfirmation' => {
            key: 'form1[0].#subform[83].certifyUnclaimedYes[0]'
          },
          'noConfirmation' => {
            key: 'form1[0].#subform[83].certifyUnclaimedNo[0]'
          },
          'hasPlotExpenseResponsibility' => {
            key: 'form1[0].#subform[83].ResponsibleForPlotIntermentCostYes[0]'
          },
          'noPlotExpenseResponsibility' => {
            key: 'form1[0].#subform[83].ResponsibleForPlotIntermentCostNo[0]'
          },
          'hasTransportation' => {
            key: 'form1[0].#subform[83].ResponsibleForTransportationYes[0]'
          },
          'noTransportation' => {
            key: 'form1[0].#subform[83].ResponsibleForTransportationNo[0]'
          },
          'hasProcessOption' => {
            key: 'form1[0].#subform[83].WantClaimFDCProcessedYes[0]'
          },
          'noProcessOption' => {
            key: 'form1[0].#subform[83].WantClaimFDCProcessedNo[0]'
          },
          'signature' => {
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
          'veteranSocialSecurityNumber3' => {
            'first' => {
              key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_FirstThreeNumbers[2]'
            },
            'second' => {
              key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_SecondTwoNumbers[2]'
            },
            'third' => {
              key: 'form1[0].#subform[83].#subform[84].VeteransSocialSecurityNumber_LastFourNumbers[2]'
            }
          }
        }.freeze
        # rubocop:enable Layout/LineLength

        ##
        # This method sanitizes a phone number by removing dashes
        #
        # @param phone [String] The phone number to be sanitized.
        #
        # @return [String]
        def sanitize_phone(phone)
          phone.gsub('-', '')
        end

        ##
        # Splits a phone number from a hash into its component parts
        #
        # @param hash [Hash]
        # @param key [String, Symbol]
        #
        # @return [Hash]
        def split_phone(hash, key)
          phone = hash[key]
          return if phone.blank?

          phone = sanitize_phone(phone)
          hash[key] = {
            'first' => phone[0..2],
            'second' => phone[3..5],
            'third' => phone[6..9]
          }
        end

        ##
        # Splits a postal code into its first five and last four digits if present
        # If the postal code is blank, the method returns nil
        #
        # @param hash [Hash]
        #
        # @return [Hash]
        def split_postal_code(hash)
          postal_code = hash['claimantAddress']['postalCode']
          return if postal_code.blank?

          hash['claimantAddress']['postalCode'] = {
            'firstFive' => postal_code[0..4],
            'lastFour' => postal_code[6..10]
          }
        end

        ##
        # Expands a boolean checkbox value into a hash with "YES" or "NO" responses
        #
        # @param value [Boolean]
        # @param key [String]
        #
        # @return [Hash]
        def expand_checkbox(value, key)
          {
            "has#{key}" => value == true ? 'YES' : nil,
            "no#{key}" => value == false ? 'NO' : nil
          }
        end

        ##
        # Expands a checkbox value within a hash and updates it in place
        #
        # @param hash [Hash]
        # @param key [String]
        #
        # @return [Hash]
        def expand_checkbox_in_place(hash, key)
          hash.merge!(expand_checkbox(hash[key], StringHelpers.capitalize_only(key)))
        end

        ##
        # Expands tours of duty by formatting a few fields
        #
        # @param tours_of_duty [Array<Hash>]
        #
        # @return [Hash]
        def expand_tours_of_duty(tours_of_duty)
          return if tours_of_duty.blank?

          tours_of_duty.each do |tour_of_duty|
            expand_date_range(tour_of_duty, 'dateRange')
            tour_of_duty['rank'] = combine_hash(tour_of_duty, %w[serviceBranch rank], ', ')
            tour_of_duty['militaryServiceNumber'] = @form_data['militaryServiceNumber']
          end
        end

        ##
        # Converts the location of death by formatting facility details and adjusting specific location values
        #
        # @return [Hash]
        def convert_location_of_death
          location_of_death = @form_data['locationOfDeath']
          return if location_of_death.blank?

          location = location_of_death['location']
          options = @form_data[location]
          if options.present? && location != 'other'
            location_of_death['placeAndLocation'] = "#{options['facilityName']} - #{options['facilityLocation']}"
          end

          @form_data.delete(location)

          location_of_death['location'] = 'nursingHomeUnpaid' if location == 'atHome'

          expand_checkbox_as_hash(@form_data['locationOfDeath'], 'location')
        end

        ##
        # Expands the burial allowance request by ensuring values are formatted as 'On' or nil
        #
        # @return [void]
        def expand_burial_allowance
          burial_allowance = @form_data['burialAllowanceRequested']
          return if burial_allowance.blank?

          burial_allowance.each do |key, value|
            burial_allowance[key] = value.present? ? 'On' : nil
          end

          @form_data['burialAllowanceRequested'] = {
            'checkbox' => burial_allowance
          }
        end

        ##
        # Expands cemetery location details by extracting relevant information
        #
        # @return [void]
        def expand_cemetery_location
          cemetery_location = @form_data['cemeteryLocation']
          return if cemetery_location.blank?

          @form_data['stateCemeteryOrTribalTrustName'] = cemetery_location['name'] if cemetery_location['name'].present?
          @form_data['stateCemeteryOrTribalTrustZip'] = cemetery_location['zip'] if cemetery_location['zip'].present?
        end

        ##
        # Expands tribal land location details by extracting relevant information
        #
        # @return [void]
        def expand_tribal_land_location
          cemetery_location = @form_data['tribalLandLocation']
          return if cemetery_location.blank?

          @form_data['stateCemeteryOrTribalTrustName'] = cemetery_location['name'] if cemetery_location['name'].present?
          @form_data['stateCemeteryOrTribalTrustZip'] = cemetery_location['zip'] if cemetery_location['zip'].present?
        end

        ##
        # Extracts and normalizes the VA file number
        #
        # VA file number can be up to 10 digits long; An optional leading 'c' or 'C' followed by
        # 7-9 digits. The file number field on the 4142 form has space for 9 characters so trim the
        # potential leading 'c' to ensure the file number will fit into the form without overflow.
        #
        # @param va_file_number [String, nil]
        #
        # @return [String, nil]
        def extract_va_file_number(va_file_number)
          return va_file_number if va_file_number.blank? || va_file_number.length < 10

          va_file_number.sub(/^[Cc]/, '')
        end

        ##
        # Converts a boolean value into a checkbox selection
        #
        # This method returns 'On' if the value is truthy, otherwise it returns 'Off'
        # Override for on/off vs 1/off @see FormHelper
        #
        # @param value [Boolean]
        #
        # @return [String]e
        def select_checkbox(value)
          value ? 'On' : 'Off'
        end

        ##
        # Expands a value from a hash into a 'checkbox' structure
        #
        # Override for 'On' vs true @see FormHelper
        #
        # @param hash [Hash]
        # @param key [Symbol]
        #
        # @return [void]
        def expand_checkbox_as_hash(hash, key)
          value = hash.try(:[], key)
          return if value.blank?

          hash['checkbox'] = {
            value => 'On'
          }
        end

        ##
        # Expands the 'confirmation' field in the form data
        #
        # @return [void]
        def expand_confirmation_question
          if @form_data['confirmation'].present?
            confirmation = @form_data['confirmation']
            @form_data['confirmation'] = confirmation['checkBox']
            expand_checkbox_in_place(@form_data, 'confirmation')
          end
        end

        ##
        # Expands the 'cemetaryLocationQuestion' to other form_data fields
        #
        # @return [void]
        def expand_location_question
          cemetery_location = @form_data['cemetaryLocationQuestion']
          @form_data['cemetaryLocationQuestionCemetery'] = select_checkbox(cemetery_location == 'cemetery')
          @form_data['cemetaryLocationQuestionTribal'] = select_checkbox(cemetery_location == 'tribalLand')
          @form_data['cemetaryLocationQuestionNone'] = select_checkbox(cemetery_location == 'none')
        end

        ##
        # Combines the previous names and their corresponding service branches into a formatted string
        #
        # @param previous_names [Array<Hash>]
        #
        # @return [String, nil]
        def combine_previous_names_and_service(previous_names)
          return if previous_names.blank?

          previous_names.map do |previous_name|
            "#{combine_full_name(previous_name)} (#{previous_name['serviceBranch']})"
          end.join('; ')
        end

        ##
        # Adjusts the spacing of the 'amountGovtContribution' value by right-justifying it
        #
        # @return [void, nil]
        def format_currency_spacing
          return if @form_data['amountGovtContribution'].blank?

          @form_data['amountGovtContribution'] = @form_data['amountGovtContribution'].rjust(5)
        end

        ##
        # Sets the 'cemeteryLocationQuestion' field to 'none' if the 'nationalOrFederal' field is present and truthy.
        #
        # @return [void, nil]
        def set_state_to_no_if_national
          national = @form_data['nationalOrFederal']
          @form_data['cemetaryLocationQuestion'] = 'none' if national
        end

        ##
        # The crux of the class, this method merges all the data that has been converted into @form_data
        #
        # @param _options [Hash]
        #
        # @return [Hash]
        # rubocop:disable Metrics/MethodLength
        def merge_fields(_options = {})
          expand_signature(@form_data['claimantFullName'])

          %w[veteranFullName claimantFullName].each do |attr|
            extract_middle_i(@form_data, attr)
          end

          %w[veteranDateOfBirth deathDate burialDate claimantDateOfBirth].each do |attr|
            @form_data[attr] = split_date(@form_data[attr])
          end

          ssn = @form_data['veteranSocialSecurityNumber']
          ['', '2', '3'].each do |suffix|
            @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
          end

          @form_data['claimantSocialSecurityNumber'] = split_ssn(@form_data['claimantSocialSecurityNumber'])

          relationship_to_veteran = @form_data['relationshipToVeteran']
          @form_data['relationshipToVeteran'] = {
            'spouse' => select_checkbox(relationship_to_veteran == 'spouse'),
            'child' => select_checkbox(relationship_to_veteran == 'child'),
            'executor' => select_checkbox(relationship_to_veteran == 'executor'),
            'parent' => select_checkbox(relationship_to_veteran == 'parent'),
            'funeralDirector' => select_checkbox(relationship_to_veteran == 'funeralDirector'),
            'otherFamily' => select_checkbox(relationship_to_veteran == 'otherFamily')
          }

          # special case for transportation being the only option selected.
          final_resting_place = @form_data.dig('finalRestingPlace', 'location')
          if final_resting_place.present?
            @form_data['finalRestingPlace']['location'] = {
              'cemetery' => select_checkbox(final_resting_place == 'cemetery'),
              'privateResidence' => select_checkbox(final_resting_place == 'privateResidence'),
              'mausoleum' => select_checkbox(final_resting_place == 'mausoleum'),
              'other' => select_checkbox(final_resting_place == 'other')
            }
          end

          expand_cemetery_location
          expand_tribal_land_location

          # special case: the UI only has a 'yes' checkbox, so the PDF 'noTransportation' checkbox can never be true.
          @form_data['hasTransportation'] = @form_data['transportation'] == true ? 'YES' : nil

          # special case: these fields were built as checkboxes instead of radios, so usual radio logic can't be used.
          burial_expense_responsibility = @form_data['burialExpenseResponsibility']
          @form_data['hasBurialExpenseResponsibility'] = burial_expense_responsibility ? 'On' : nil

          # special case: these fields were built as checkboxes instead of radios, so usual radio logic can't be used.
          plot_expense_responsibility = @form_data['plotExpenseResponsibility']
          @form_data['hasPlotExpenseResponsibility'] = plot_expense_responsibility ? 'On' : nil

          # special case: these fields were built as checkboxes instead of radios, so usual radio logic can't be used.
          process_option = @form_data['processOption']
          @form_data['hasProcessOption'] = process_option ? 'On' : nil
          @form_data['noProcessOption'] = process_option ? nil : 'On'

          expand_confirmation_question
          set_state_to_no_if_national
          expand_location_question

          split_phone(@form_data, 'claimantPhone')

          split_postal_code(@form_data)

          expand_tours_of_duty(@form_data['toursOfDuty'])

          @form_data['previousNames'] = combine_previous_names_and_service(@form_data['previousNames'])

          @form_data['vaFileNumber'] = extract_va_file_number(@form_data['vaFileNumber'])

          expand_burial_allowance

          convert_location_of_death

          format_currency_spacing

          %w[
            nationalOrFederal
            govtContributions
            previouslyReceivedAllowance
            allowanceStatementOfTruth
          ].each do |attr|
            expand_checkbox_in_place(@form_data, attr)
          end

          @form_data
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
