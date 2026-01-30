# frozen_string_literal: true

require 'dependents/error_classes'

# rubocop:disable Metrics/ClassLength

module PdfFill
  module Forms
    class Va686c674v2 < FormBase
      include FormHelper
      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'veteran_information' => {
          'full_name' => {
            'first' => {
              key: 'form1[0].#subform[17].VeteranFirstName[0]',
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S NAME'
            },
            'middleInitial' => {
              key: 'form1[0].#subform[17].VeteranMiddleInitial1[0]',
              limit: 1,
              question_num: 1,
              question_suffix: 'B',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S NAME'
            },
            'last' => {
              key: 'form1[0].#subform[17].VeteranLastName[0]',
              limit: 18,
              question_num: 1,
              question_suffix: 'C',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S NAME'
            }
            # suffix
          },
          'ssn' => {
            'first' => {
              key: 'form1[0].#subform[17].Veterans_SocialSecurityNumber_FirstThreeNumbers[0]',
              limit: 3,
              question_num: 4,
              question_suffix: 'A',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S SOCIAL SECURITY NUMBER'
            },
            'second' => {
              key: 'form1[0].#subform[17].Veterans_SocialSecurityNumber_SecondTwoNumbers[0]',
              limit: 2,
              question_num: 4,
              question_suffix: 'B',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S SOCIAL SECURITY NUMBER'
            },
            'third' => {
              key: 'form1[0].#subform[17].Veterans_SocialSecurityNumber_LastFourNumbers[0]',
              limit: 4,
              question_num: 4,
              question_suffix: 'C',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S SOCIAL SECURITY NUMBER'
            }
          },
          'va_file_number' => {
            key: 'form1[0].#subform[17].VAFileNumber[0]',
            limit: 9,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VA FILE NUMBER (If known)'
          },
          'birth_date' => {
            'month' => {
              key: 'form1[0].#subform[17].DOBmonth[0]',
              limit: 2,
              question_num: 4,
              question_suffix: 'A',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BIRTH (MM-DD-YYYY)'
            },
            'day' => {
              key: 'form1[0].#subform[17].DOBday[0]',
              limit: 2,
              question_num: 4,
              question_suffix: 'B',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BIRTH (MM-DD-YYYY)'
            },
            'year' => {
              key: 'form1[0].#subform[17].DOByear[0]',
              limit: 4,
              question_num: 4,
              question_suffix: 'C',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S DATE OF BIRTH (MM-DD-YYYY)'
            }
          },
          # claimant's name
          # claimant's social security number
          'service_number' => {
            key: 'form1[0].#subform[17].VeteransServiceNumber[0]',
            limit: 9,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S SERVICE NUMBER (If applicable)'
          }
        }, # end veteran_information
        'dependents_application' => {
          'veteran_contact_information' => {
            'phone_number' => {
              'phone_area_code' => {
                key: 'form1[0].#subform[17].TelephoneNumber_AreaCode[0]',
                limit: 3,
                question_num: 8,
                question_suffix: 'A',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > TELEPHONE NUMBER'
              },
              'phone_first_three_numbers' => {
                key: 'form1[0].#subform[17].TelephoneNumber_FirstThreeNumbers[0]',
                limit: 3,
                question_num: 8,
                question_suffix: 'B',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > TELEPHONE NUMBER'
              },
              'phone_last_four_numbers' => {
                key: 'form1[0].#subform[17].TelephoneNumber_LastFourNumbers[0]',
                limit: 4,
                question_num: 8,
                question_suffix: 'C',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > TELEPHONE NUMBER'
              }
            },
            'international_phone_number' => {
              key: 'form1[0].#subform[17].TelephoneNumber_International[0]',
              limit: 13,
              question_num: 8,
              question_suffix: 'C',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > Enter International Phone Number'
            },
            'email_address' => {
              key: 'form1[0].#subform[17].Email_Address[0]',
              limit: 30,
              question_num: 9,
              question_suffix: 'A',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > E-MAIL ADDRESS'
            },
            'electronic_correspondence' => {
              key: 'form1[0].#subform[17].EmailAddressConsent[0]'
            },
            'veteran_address' => {
              'street' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_NumberAndStreet[0]',
                limit: 30,
                question_num: 10,
                question_suffix: 'A',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > MAILING ADDRESS OF VETERAN/CLAIMANT'
              },
              'street2' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
                limit: 5,
                question_num: 10,
                question_suffix: 'B',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > MAILING ADDRESS OF VETERAN/CLAIMANT'
              },
              # street3
              'city' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_City[0]',
                limit: 18,
                question_num: 10,
                question_suffix: 'C',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > MAILING ADDRESS OF VETERAN/CLAIMANT'
              },
              'state' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_StateOrProvince[0]',
                limit: 2,
                question_num: 10,
                question_suffix: 'D',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > MAILING ADDRESS OF VETERAN/CLAIMANT'
              },
              'country_name' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_Country[0]',
                limit: 2,
                question_num: 10,
                question_suffix: 'E',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > MAILING ADDRESS OF VETERAN/CLAIMANT'
              },
              'zip_code' => {
                'firstFive' => {
                  key: 'form1[0].#subform[17].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]',
                  limit: 5,
                  question_num: 10,
                  question_suffix: 'F',
                  question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > MAILING ADDRESS OF VETERAN/CLAIMANT'
                },
                'lastFour' => {
                  key: 'form1[0].#subform[17].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]',
                  limit: 4,
                  question_num: 10,
                  question_suffix: 'G',
                  question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > MAILING ADDRESS OF VETERAN/CLAIMANT'
                }
              }
            }
          }, # end veteran_contact_information
          'does_live_with_spouse' => {
            'spouse_does_live_with_veteran' => {
              'spouse_does_live_with_veteran_yes' => { key: 'form1[0].#subform[17].YES[1]' },
              'spouse_does_live_with_veteran_no' => { key: 'form1[0].#subform[17].NO[1]' }
            },
            'current_spouse_reason_for_separation' => {
              key: 'form1[0].#subform[17].Reasonforseparation[0]',
              limit: 20,
              question_num: 13,
              question_suffix: 'A',
              question_text: 'INFORMATION NEEDED TO ADD SPOUSE > REASON FOR SEPARATION'
            },
            'address' => {
              'street' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_NumberAndStreet[1]',
                limit: 30,
                question_num: 13,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > LIVING WITH SPOUSE > ADDRESS'
              },
              'street2' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_ApartmentOrUnitNumber[1]',
                limit: 5,
                question_num: 13,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > LIVING WITH SPOUSE > ADDRESS'
              },
              'city' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_City[1]',
                limit: 18,
                question_num: 13,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > LIVING WITH SPOUSE > CITY'
              },
              'state' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_StateOrProvince[1]',
                limit: 2,
                question_num: 13,
                question_suffix: 'D',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > LIVING WITH SPOUSE > STATE'
              },
              'country_name' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_Country[1]',
                limit: 2,
                question_num: 13,
                question_suffix: 'E',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > LIVING WITH SPOUSE > COUNTRY'
              },
              'postal_code' => {
                'firstFive' => {
                  key: 'form1[0].#subform[17].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[1]',
                  limit: 5,
                  question_num: 13,
                  question_suffix: 'F',
                  question_text: 'INFORMATION NEEDED TO ADD SPOUSE > LIVING WITH SPOUSE > ZIP FIRST 5'
                }, # end of zip first 5
                'lastFour' => {
                  key: 'form1[0].#subform[17].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[1]',
                  limit: 4,
                  question_num: 13,
                  question_suffix: 'G',
                  question_text: 'INFORMATION NEEDED TO ADD SPOUSE > LIVING WITH SPOUSE > ZIP LAST 4'
                } # end of zip last 4
              } # end of zip
            } # end of address
          },
          'spouse_information' => {
            'full_name' => {
              'first' => {
                key: 'form1[0].#subform[17].SPOUSEFirstName[0]',
                limit: 12,
                question_num: 11,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > SPOUSE\'S NAME'
              },
              'middleInitial' => {
                key: 'form1[0].#subform[17].SPOUSEMiddleInitial1[0]',
                limit: 1,
                question_num: 11,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > SPOUSE\'S NAME'
              },
              'last' => {
                key: 'form1[0].#subform[17].SPOUSELastName[0]',
                limit: 18,
                question_num: 11,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > SPOUSE\'S NAME'
              }
            }, # end full_name
            'birth_date' => {
              'month' => {
                key: 'form1[0].#subform[17].DOBmonth[1]',
                limit: 2,
                question_num: 11,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > SPOUSE\'S DOB MONTH'
              },
              'day' => {
                key: 'form1[0].#subform[17].DOBday[1]',
                limit: 2,
                question_num: 11,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > SPOUSE\'S DOB DAY'
              },
              'year' => {
                key: 'form1[0].#subform[17].DOByear[1]',
                limit: 4,
                question_num: 11,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > SPOUSE\'S DOB YEAR'
              }
            }, # end birth_date
            'ssn' => {
              'first' => {
                key: 'form1[0].#subform[17].SpouseSocialSecurityNumber_FirstThreeNumbers[0]',
                limit: 3,
                question_num: 11,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > SPOUSE\'S SSN FIRST THREE NUMBERS'
              },
              'second' => {
                key: 'form1[0].#subform[17].SpouseSocialSecurityNumber_SecondTwoNumbers[0]',
                limit: 2,
                question_num: 11,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > SPOUSE\'S SSN SECOND TWO NUMBERS'
              },
              'third' => {
                key: 'form1[0].#subform[17].SpouseSocialSecurityNumber_LastFourNumbers[0]',
                limit: 4,
                question_num: 11,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > SPOUSE\'S SSN LAST FOUR NUMBERS'
              }
            }, # end spouse ssn
            'va_file_number' => { # XXX this group needs three parts like SSN, name looks v. sim
              key: 'form1[0].#subform[17].SpouseVAFileNumber[0]',
              limit: 9,
              question_num: 12,
              question_suffix: 'B',
              question_text: 'Spouse\'s VA File Number (If Applicable)'
            }, # end of spouse va file number
            'service_number' => {
              key: 'form1[0].#subform[17].SPOUSEServiceNumber[0]',
              limit: 9,
              question_num: 12,
              question_suffix: 'C',
              question_text: 'INFORMATION NEEDED TO ADD SPOUSE > IS YOUR SPOUSE A VETERAN'
            }, # end of spouse service number
            'is_veteran' => {
              'is_veteran_yes' => { key: 'form1[0].#subform[17].YES[0]' },
              'is_veteran_no' => { key: 'form1[0].#subform[17].NO[0]' }
            }
          },
          # ------------  SECTION II: INFORMATION NEEDED TO ADD SPOUSE  ------------ #
          'current_marriage_information' => {
            'date' => {
              'month' => {
                key: 'form1[0].#subform[17].DOMARRIAGEmonth[0]',
                limit: 2,
                question_num: 11,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > DATE OF MARRIAGE MONTH'
              },
              'day' => {
                key: 'form1[0].#subform[17].DOMARRIAGEday[0]',
                limit: 2,
                question_num: 11,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > DATE OF MARRIAGE DAY'
              },
              'year' => {
                key: 'form1[0].#subform[17].DOMARRIAGEyear[0]',
                limit: 4,
                question_num: 11,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > DATE OF MARRIAGE YEAR'
              }
            },
            'location' => {
              'city' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_City[2]',
                limit: 18,
                question_num: 11,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > MARRIAGE CITY'
              },
              'state' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_StateOrProvince[2]',
                limit: 2,
                question_num: 11,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > MARRIAGE STATE'
              },
              'country' => {
                key: 'form1[0].#subform[17].CurrentMailingAddress_Country[2]',
                limit: 2,
                question_num: 11,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD SPOUSE > MARRIAGE COUNTRY'
              }
            }, # end location
            'type_of_marriage' => {
              'civil_ceremony' => {
                key: 'form1[0].#subform[17].CivilCeremony[0]'
              },
              'religious_ceremony' => {
                key: 'form1[0].#subform[17].ReligiousCeremony[0]'
              },
              'common_law' => {
                key: 'form1[0].#subform[17].CommonLaw[0]'
              },
              'tribal' => {
                key: 'form1[0].#subform[17].Tribal[0]'
              },
              'proxy' => {
                key: 'form1[0].#subform[17].Proxy[0]'
              },
              'other' => {
                key: 'form1[0].#subform[17].OTHER_Explain[0]'
              }
            }, # end of marriage type
            'type_other' => {
              key: 'form1[0].#subform[17].Other[0]',
              limit: 9,
              question_num: 11,
              question_suffix: 'A',
              question_text: 'INFORMATION NEEDED TO ADD SPOUSE > MARRIAGE TYPE OTHER EXPLANATION'
            }
          }, # end current_marriage_information
          'veteran_marriage_history' => {
            limit: 4,
            first_key: 'full_name',
            'full_name' => {
              'first' => {
                key: 'veteran.previousSpouse.firstName[%iterator%]',
                limit: 12,
                question_num: 14,
                question_suffix: 'A',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE FIRST NAME'
              },
              'middleInitial' => {
                key: 'veteran.previousSpouse.middleInitial[%iterator%]',
                limit: 1,
                question_num: 14,
                question_suffix: 'B',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MIDDLE INITIAL'
              },
              'last' => {
                key: 'veteran.previousSpouse.lastName[%iterator%]',
                limit: 18,
                question_num: 14,
                question_suffix: 'C',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE LAST NAME'
              }
              # @TODO 'suffix' =>  FE has suffix but no place for it on PDF
            }, # end of end of full name
            'start_date' => {
              'month' => {
                key: 'veteran_marriage_history.start_date.month[%iterator%]',
                limit: 2,
                question_num: 14,
                question_suffix: 'E',
                question_text: 'PREVIOUS MARRIAGE HISTORY > MONTH'
              },
              'day' => {
                key: 'veteran_marriage_history.start_date.day[%iterator%]',
                limit: 2,
                question_num: 14,
                question_suffix: 'F',
                question_text: 'PREVIOUS MARRIAGE HISTORY > MONTH'
              },
              'year' => {
                key: 'veteran_marriage_history.start_date.year[%iterator%]',
                limit: 4,
                question_num: 14,
                question_suffix: 'G',
                question_text: 'PREVIOUS MARRIAGE HISTORY > YEAR'
              }
            }, # end of start_date
            'start_location' => {
              'location' => {
                'city' => {
                  key: 'veteran.previousMarriage.startCity[%iterator%]',
                  limit: 18,
                  question_num: 14,
                  question_suffix: 'H',
                  question_text: 'PREVIOUS MARRIAGE HISTORY > CITY'
                },
                'state' => {
                  key: 'veteran_marriage_history.start_location.state[%iterator%]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'I',
                  question_text: 'PREVIOUS MARRIAGE HISTORY > STATE'
                },
                'country' => {
                  key: 'veteran_marriage_history.start_location.country[%iterator%]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'J',
                  question_text: 'PREVIOUS MARRIAGE HISTORY > COUNTRY'
                }
              }
            }, # end of start_location
            'reason_marriage_ended' => {
              'death' => { key: 'veteran_marriage_history.reason_marriage_ended.death[%iterator%]' },
              'divorce' => { key: 'veteran_marriage_history.reason_marriage_ended.divorce[%iterator%]' },
              'annulment' => { key: 'veteran_marriage_history.reason_marriage_ended.annulment[%iterator%]' },
              'other' => { key: 'veteran_marriage_history.reason_marriage_ended.other[%iterator%]' }
            },
            'other_reason_marriage_ended' => {
              key: 'veteran_marriage_history.reason_marriage_ended_other[%iterator%]',
              question_num: 14,
              question_suffix: 'K',
              question_text: 'PREVIOUS MARRIAGE HISTORY > REASON FOR TERMINATION'
            },
            'end_date' => {
              'month' => {
                key: 'veteran_marriage_history.end_date.month[%iterator%]',
                limit: 2,
                question_num: 14,
                question_suffix: 'L',
                question_text: 'PREVIOUS MARRIAGE HISTORY > TERMINATION MONTH'
              },
              'day' => {
                key: 'veteran_marriage_history.end_date.day[%iterator%]',
                limit: 2,
                question_num: 14,
                question_suffix: 'M',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  TERMINATION DAY'
              },
              'year' => {
                key: 'veteran_marriage_history.end_date.year[%iterator%]',
                limit: 4,
                question_num: 14,
                question_suffix: 'N',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  TERMINATION YEAR'
              }
            }, # end of end date
            'end_location' => {
              'location' => {
                'city' => {
                  key: 'veteran.previousMarriage.terminationCity[%iterator%]',
                  limit: 18,
                  question_num: 14,
                  question_suffix: 'O',
                  question_text: 'PREVIOUS MARRIAGE HISTORY >  TERMINATION CITY'
                },
                'state' => {
                  key: 'veteran.previousMarriage.terminationState[%iterator%]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'P',
                  question_text: 'PREVIOUS MARRIAGE HISTORY >  TERMINATION STATE'
                },
                'country' => {
                  key: 'veteran.previousMarriage.terminationCountry[%iterator%]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'Q',
                  question_text: 'PREVIOUS MARRIAGE HISTORY > TERMINATION COUNTRY'
                }
              }
            } # end end_location
          }, # end veteran_marriage_history
          'spouse_marriage_history' => {
            limit: 4,
            first_key: 'full_name',
            'full_name' => {
              'first' => {
                key: 'veteranSpouse.previousSpouse.firstName[%iterator%]',
                limit: 12,
                question_num: 15,
                question_suffix: 'A',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  SPOUSES PREVIOUS SPOUSE FIRST NAME'
              },
              'middleInitial' => {
                key: 'veteranSpouse.previousSpouse.middleInitial[%iterator%]',
                limit: 1,
                question_num: 15,
                question_suffix: 'B',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  SPOUSES PREVIOUS SPOUSE MIDDLE INITIAL'
              },
              'last' => {
                key: 'veteranSpouse.previousSpouse.lastName[%iterator%]',
                limit: 18,
                question_num: 15,
                question_suffix: 'C',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  SPOUSES PREVIOUS SPOUSE LAST NAME'
              }
              # @TODO 'suffix' =>  FE has suffix but no place for it on PDF
            }, # end of full name
            'start_date' => {
              'month' => {
                key: 'spouse_marriage_history.start_date.month[%iterator%]',
                limit: 2,
                question_num: 15,
                question_suffix: 'A',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE DATE MONTH'
              },
              'day' => {
                key: 'spouse_marriage_history.start_date.day[%iterator%]',
                limit: 2,
                question_num: 15,
                question_suffix: 'B',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE DATE DAY'
              },
              'year' => {
                key: 'spouse_marriage_history.start_date.year[%iterator%]',
                limit: 4,
                question_num: 15,
                question_suffix: 'C',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE DATE YEAR'
              }
            }, # end of start date
            'start_location' => {
              'location' => {
                'city' => {
                  key: 'spouse_marriage_history.start_location.city[%iterator%]',
                  limit: 18,
                  question_num: 15,
                  question_suffix: 'D',
                  question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE LOCATION CITY'
                },
                'state' => {
                  key: 'spouse_marriage_history.start_location.state[%iterator%]',
                  limit: 2,
                  question_num: 15,
                  question_suffix: 'E',
                  question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE LOCATION STATE'
                },
                'country' => {
                  key: 'spouse_marriage_history.start_location.country[%iterator%]',
                  limit: 2,
                  question_num: 15,
                  question_suffix: 'F',
                  question_text: 'PREVIOUS MARRIAGE HISTORY > PREVIOUS SPOUSE MARRIAGE LOCATION COUNTRY'
                }
              }
            }, # end start_location
            'reason_marriage_ended' => {
              'death' => { key: 'spouse_marriage_history.reason_marriage_ended.death[%iterator%]' },
              'divorce' => { key: 'spouse_marriage_history.reason_marriage_ended.divorce[%iterator%]' },
              'annulment' => { key: 'spouse_marriage_history.reason_marriage_ended.annulment[%iterator%]' },
              'other' => { key: 'spouse_marriage_history.reason_marriage_ended.other[%iterator%]' }
            },
            'other_reason_marriage_ended' => {
              key: 'spouse_marriage_history.reason_marriage_ended_other[%iterator%]',
              question_num: 15,
              question_suffix: 'G',
              question_text: 'PREVIOUS MARRIAGE HISTORY > REASON FOR TERMINATION'
            },
            'end_date' => {
              'month' => {
                key: 'spouse_marriage_history.end_date.month[%iterator%]',
                limit: 2,
                question_num: 15,
                question_suffix: 'H',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE DATE ENDED MONTH'
              }, # end of end date month
              'day' => {
                key: 'spouse_marriage_history.end_date.day[%iterator%]',
                limit: 2,
                question_num: 15,
                question_suffix: 'I',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE DATE ENDED DAY'
              }, # end of end date day
              'year' => {
                key: 'spouse_marriage_history.end_date.year[%iterator%]',
                limit: 4,
                question_num: 15,
                question_suffix: 'J',
                question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE DATE ENDED YEAR'
              } # end of end date year
            }, # end of end date
            'end_location' => {
              'location' => {
                'city' => {
                  key: 'spouse_marriage_history.end_location.city[%iterator%]',
                  limit: 18,
                  question_num: 15,
                  question_suffix: 'K',
                  question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE TERMINATION CITY'
                },
                'state' => {
                  key: 'spouse_marriage_history.end_location.state[%iterator%]',
                  limit: 2,
                  question_num: 15,
                  question_suffix: 'L',
                  question_text: 'PREVIOUS MARRIAGE HISTORY >  PREVIOUS SPOUSE MARRIAGE TERMINATION STATE'
                },
                'country' => {
                  key: 'spouse_marriage_history.end_location.country[%iterator%]',
                  limit: 2,
                  question_num: 15,
                  question_suffix: 'M',
                  question_text: 'PREVIOUS MARRIAGE HISTORY > PREVIOUS SPOUSE MARRIAGE TERMINATION COUNTRY'
                }
              }
            } # end location
          }, # end spouse_marriage_history
          # -----------------  SECTION III: INFORMATION NEEDED TO ADD CHILD(REN)  ----------------- #
          'children_to_add' => {
            limit: 6,
            first_key: 'full_name',
            'full_name' => {
              'first' => {
                key: 'children_to_add.full_name.first[%iterator%]',
                limit: 12,
                question_num: 16,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > FIRST NAME'
              },
              'middleInitial' => {
                key: 'children_to_add.full_name.middleInitial[%iterator%]',
                limit: 1,
                question_num: 16,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > MIDDLE INITIAL'
              },
              'last' => {
                key: 'children_to_add.full_name.last[%iterator%]',
                limit: 18,
                question_num: 16,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > LAST NAME'
              }
              # @TODO 'suffix' =>  FE has suffix but no place for it on PDF
            }, # end of full name
            'ssn' => {
              'first' => {
                key: 'children_to_add.ssn.first[%iterator%]',
                limit: 3,
                question_num: 16,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > FIRST THREE SSN'
              }, # end of ssn first three
              'second' => {
                key: 'children_to_add.ssn.second[%iterator%]',
                limit: 2,
                question_num: 16,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > SECOND TWO SSN'
              }, # end of second two
              'third' => {
                key: 'children_to_add.ssn.third[%iterator%]',
                limit: 4,
                question_num: 16,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > LAST FOUR SSN'
              } # end of last four
            }, # end of ssn
            'birth_date' => {
              'month' => {
                key: 'children_to_add.birth_date.month[%iterator%]',
                limit: 2,
                question_num: 16,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > THEIR BIRTHDAY MONTH'
              },
              'day' => {
                key: 'children_to_add.birth_date.day[%iterator%]',
                limit: 4,
                question_num: 16,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > THEIR BIRTHDAY DAY'
              },
              'year' => {
                key: 'children_to_add.birth_date.year[%iterator%]',
                limit: 4,
                question_num: 16,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > THEIR BIRTHDAY YEAR'
              }
            }, # birth_date
            'birth_location' => {
              'location' => {
                'city' => {
                  key: 'children_to_add.place_of_birth.city[%iterator%]',
                  limit: 18,
                  question_num: 16,
                  question_suffix: 'A',
                  question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > PLACE OF BIRTH > CITY'
                },
                'state' => {
                  key: 'children_to_add.place_of_birth.state[%iterator%]',
                  limit: 2,
                  question_num: 16,
                  question_suffix: 'B',
                  question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > PLACE OF BIRTH > STATE'
                },
                'country' => {
                  key: 'children_to_add.place_of_birth.country[%iterator%]',
                  limit: 2,
                  question_num: 16,
                  question_suffix: 'C',
                  question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > PLACE OF BIRTH > COUNTRY'
                }
              }
            }, # end birth_location
            'address' => {
              'street' => {
                key: 'children_to_add.child_address_info.address.address_line1[%iterator%]',
                limit: 27,
                question_num: 16,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > ADDRESS'
              }, # end of address line1
              'street2' => {
                key: 'children_to_add.child_address_info.address.address_line2[%iterator%]',
                limit: 5,
                question_num: 16,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > ADDRESS'
              },
              'city' => {
                key: 'children_to_add.child_address_info.address.city[%iterator%]',
                limit: 18,
                question_num: 16,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > CITY'
              }, # end of city
              'state' => {
                key: 'children_to_add.child_address_info.address.state_code[%iterator%]',
                limit: 2,
                question_num: 16,
                question_suffix: 'D',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > STATE'
              },
              'country' => {
                key: 'children_to_add.child_address_info.address.country_name[%iterator%]',
                limit: 2,
                question_num: 16,
                question_suffix: 'E',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > COUNTRY'
              },
              'postal_code' => {
                'firstFive' => {
                  key: 'children_to_add.child_address_info.address.zip_code.first_five[%iterator%]',
                  limit: 5,
                  question_num: 16,
                  question_suffix: 'F',
                  question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > ZIP'
                },
                'lastFour' => {
                  key: 'children_to_add.child_address_info.address.zip_code.last_four[%iterator%]',
                  limit: 4,
                  question_num: 16,
                  question_suffix: 'G',
                  question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > ZIP'
                }
              }
            }, # end address
            'living_with' => {
              'first' => {
                key: 'children_to_add.child_address_info.person_child_lives_with.first[%iterator%]',
                limit: 12,
                question_num: 16,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > FIRST NAME'
              }, # end of first name
              'middleInitial' => {
                key: 'children_to_add.child_address_info.person_child_lives_with.middleInitial[%iterator%]',
                limit: 1,
                question_num: 16,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > MIDDLE'
              }, # end of middle initial
              'last' => {
                key: 'children_to_add.child_address_info.person_child_lives_with.last[%iterator%]',
                limit: 18,
                question_num: 16,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > CHILD DOES NOT LIVE WITH CLAIMANT > LAST NAME'
              } # end of last name
            }, # end living_with
            'relationship_to_child' => {
              'adopted' => { key: 'children_to_add.child_status.adopted[%iterator%]' },
              'stepchild' => { key: 'children_to_add.child_status.stepchild[%iterator%]' }
            },
            'is_biological_child' => { key: 'children_to_add.child_status.biological[%iterator%]' },
            'does_child_have_permanent_disability' => {
              key: 'children_to_add.child_status.incapable_self_support[%iterator%]'
            },
            'marriage_end_date' => {
              'month' => {
                key: 'children_to_add.previous_marriage_details.date_marriage_ended.month[%iterator%]',
                limit: 2,
                question_num: 16,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > END DATE OF CHILDS MARRIAGE > MONTH'
              }, # end of month
              'day' => {
                key: 'children_to_add.previous_marriage_details.date_marriage_ended.day[%iterator%]',
                limit: 2,
                question_num: 16,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > END DATE OF CHILDS MARRIAGE > DAY'
              }, # end of day
              'year' => {
                key: 'children_to_add.previous_marriage_details.date_marriage_ended.year[%iterator%]',
                limit: 4,
                question_num: 16,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > END DATE OF CHILDS MARRIAGE > YEAR'
              } # end of year
            },
            'marriage_end_reason' => {
              'declared_void' => {
                key: 'children_to_add.previous_marriage_details.reason_marriage_ended.declared_void[%iterator%]'
              },
              'annulled' => {
                key: 'children_to_add.previous_marriage_details.reason_marriage_ended.annulled[%iterator%]'
              },
              'other' => { key: 'children_to_add.previous_marriage_details.reason_marriage_ended.other[%iterator%]' }
            },
            'marriage_end_description' => {
              'reason_marriage_ended_other_line1' => {
                key:
                  'children_to_add.previous_marriage_details.reason_marriage_ended_other.' \
                  'reason_marriage_ended_other_line1[%iterator%]',
                limit: 8,
                question_num: 16,
                question_suffix: 'G', # after buttons?
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > END DATE OF CHILDS MARRIAGE > REASON LINE1'
              },
              'reason_marriage_ended_other_line2' => {
                key:
                  'children_to_add.previous_marriage_details.reason_marriage_ended_other.' \
                  'reason_marriage_ended_other_line2[%iterator%]',
                limit: 8,
                question_num: 16,
                question_suffix: 'H', # after buttons?
                question_text: 'INFORMATION NEEDED TO ADD CHILD(REN) > END DATE OF CHILDS MARRIAGE > REASON LINE2'
              }
            },
            'has_child_ever_been_married' => {
              key: 'children_to_add.child_status.child_previously_married[%iterator%]'
            },
            'school_age_in_school' => {
              key: 'children_to_add.child_status.school_age_in_school[%iterator%]'
            },
            'is_biological_child_of_spouse' => {
              'is_biological_child_of_spouse_yes' => {
                key: 'children_to_add.child_status.biological_stepchild.yes[%iterator%]'
              },
              'is_biological_child_of_spouse_no' => {
                key: 'children_to_add.child_status.biological_stepchild.no[%iterator%]'
              }
            }, # end is_biological_child_of_spouse
            'date_entered_household' => {
              'month' => { key: 'children_to_add.child_status.date_became_dependent.month[%iterator%]' },
              'day' => { key: 'children_to_add.child_status.date_became_dependent.day[%iterator%]' },
              'year' => { key: 'children_to_add.child_status.date_became_dependent.year[%iterator%]' }
            }
          }, # end children_to_add
          # ------------  SECTION IV: VETERAN REPORTING DIVORCE FROM FORMER SPOUSE  ----------------- #
          'report_divorce' => {
            'full_name' => {
              'first' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].FORMERSPOUSEFIRST[0]',
                limit: 12,
                question_num: 20,
                question_suffix: 'A',
                question_text: 'VETERAN REPORTING DIVORCE FROM FORMER SPOUSE > NAME OF FORMER SPOUSE'
              },
              'middleInitial' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].FORMERSPOUSEMiddleInitial1[0]',
                limit: 1,
                question_num: 20,
                question_suffix: 'B',
                question_text: 'VETERAN REPORTING DIVORCE FROM FORMER SPOUSE > NAME OF FORMER SPOUSE'
              },
              'last' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].FORMERSPOUSELastName[0]',
                limit: 18,
                question_num: 20,
                question_suffix: 'C',
                question_text: 'VETERAN REPORTING DIVORCE FROM FORMER SPOUSE > NAME OF FORMER SPOUSE'
              }
              # @TODO 'suffix' =>  FE has suffix but no place for it on PDF
            }, # end full_name
            'divorce_location' => {
              'location' => {
                'city' => {
                  key: 'form1[0].#subform[25].#subform[26].#subform[27].CurrentMailingAddress_City[27]',
                  limit: 18,
                  question_num: 20,
                  question_suffix: 'A',
                  question_text: 'VETERAN REPORTING DIVORCE FROM FORMER SPOUSE > PLACE OF DIVORCE'
                },
                'state' => {
                  key: 'form1[0].#subform[25].#subform[26].#subform[27].CurrentMailingAddress_StateOrProvince[27]',
                  limit: 2,
                  question_num: 20,
                  question_suffix: 'B',
                  question_text: 'VETERAN REPORTING DIVORCE FROM FORMER SPOUSE > PLACE OF DIVORCE'
                },
                'country' => {
                  key: 'form1[0].#subform[25].#subform[26].#subform[27].CurrentMailingAddress_Country[27]',
                  limit: 2,
                  question_num: 20,
                  question_suffix: 'C',
                  question_text: 'VETERAN REPORTING DIVORCE FROM FORMER SPOUSE > PLACE OF DIVORCE'
                }
              }
            },
            'date' => {
              'month' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].DATEOFDIVORCE_MONTH[0]',
                limit: 2,
                question_num: 20,
                question_suffix: 'A',
                question_text: 'VETERAN REPORTING DIVORCE FROM FORMER SPOUSE > DATE OF DIVORCE'
              },
              'day' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].DATEOFDIVORCE_DAY[0]',
                limit: 2,
                question_num: 20,
                question_suffix: 'B',
                question_text: 'VETERAN REPORTING DIVORCE FROM FORMER SPOUSE > DATE OF DIVORCE'
              },
              'year' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].DATEOFDIVORCE_YEAR[0]',
                limit: 4,
                question_num: 20,
                question_suffix: 'C',
                question_text: 'VETERAN REPORTING DIVORCE FROM FORMER SPOUSE > DATE OF DIVORCE'
              }
            }
          }, # end report_divorce
          # -----------------  SECTION V: VETERAN/CLAIMANT REPORTING ON STEPCHILD(REN)  ----------------- #
          'step_children' => {
            limit: 2,
            first_key: 'full_name',
            'biological_adopted_stepchild' => {
              'biological_adopted_stepchild_yes' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].RadioButtonList[77]'
              },
              'biological_adopted_stepchild_no' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].RadioButtonList[76]'
              }
            },
            'supporting_stepchild' => {
              'supporting_stepchild_yes' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].RadioButtonList[79]'
              },
              'supporting_stepchild_no' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].RadioButtonList[78]'
              }
            }, # end of supporting_stepchild
            'biological_stepchild' => {
              'first' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].biological_stepchild_first[%iterator%]',
                limit: 12,
                question_num: 21,
                question_suffix: 'A',
                question_text: 'NAMES OF STEPCHILD(REN) > FIRST NAME'
              },
              'middleInitial' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].biological_stepchild_middle[%iterator%]',
                question_num: 21,
                question_suffix: 'A',
                question_text: 'NAMES OF STEPCHILDREN > MIDDLE INITIAL'
              },
              'last' => {
                key: 'form1[0].#subform[25].#subform[26].#subform[27].biological_stepchild_last[%iterator%]',
                question_num: 21,
                question_suffix: 'A',
                question_text: 'NAMES OF STEPCHILDREN > LAST NAME'
              }
            },
            'full_name' => {
              'first' => {
                key: 'step_children.full_name.first[%iterator%]',
                limit: 12,
                question_num: 21,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > FIRST NAME'
              }, # end of first name of the stepchild you are supporting
              'middleInitial' => {
                key: 'step_children.full_name.middleInitial[%iterator%]',
                limit: 1,
                question_num: 21,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > MIDDLE INITIAL'
              }, # end of middle initial of the stepchild you are supporting
              'last' => {
                key: 'step_children.full_name.last[%iterator%]',
                limit: 18,
                question_num: 21,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LAST NAME'
              } # end of last name of the stepchild you are supporting
            },
            'who_does_the_stepchild_live_with' => {
              'first' => {
                key: 'step_children.who_does_the_stepchild_live_with.first[%iterator%]',
                limit: 12,
                question_num: 21,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WITH WHO > FIRST NAME'
              }, # end of first
              'middleInitial' => {
                key: 'step_children.who_does_the_stepchild_live_with.middleInitial[%iterator%]',
                limit: 1,
                question_num: 21,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WITH WHO > MIDDLE INITIAL'
              }, # end of middle
              'last' => {
                key: 'step_children.who_does_the_stepchild_live_with.last[%iterator%]',
                limit: 18,
                question_num: 21,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WITH WHO > LAST NAME'
              } # end of last
            }, # end of who_does_the_stepchild_live_with
            'address' => {
              'street' => {
                key: 'step_children.address.address_line1[%iterator%]',
                limit: 27,
                question_num: 21,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WHERE > STREET'
              },
              'street2' => {
                key: 'step_children.address.address_line2[%iterator%]',
                limit: 5,
                question_num: 21,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WHERE > STREET'
              },
              'city' => {
                key: 'step_children.address.city[%iterator%]',
                limit: 18,
                question_num: 21,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WHERE > CITY'
              },
              'state' => {
                key: 'step_children.address.state_code[%iterator%]',
                limit: 2,
                question_num: 21,
                question_suffix: 'D',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WHERE > STATE'
              },
              'country' => {
                key: 'step_children.address.country_name[%iterator%]',
                limit: 2,
                question_num: 21,
                question_suffix: 'E',
                question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WHERE > COUNTRY'
              },
              'postal_code' => {
                'firstFive' => {
                  key: 'step_children.address.zip_code.firstFive[%iterator%]',
                  limit: 5,
                  question_num: 21,
                  question_suffix: 'F',
                  question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WHERE > ZIPCODE FIRST FIVE'
                },
                'lastFour' => {
                  key: 'step_children.address.zip_code.lastFour[%iterator%]',
                  limit: 4,
                  question_num: 21,
                  question_suffix: 'G',
                  question_text: 'INFORMATION NEEDED TO ADD A STEPCHILD > LIVING WHERE > ZIPCODE LAST FOUR'
                }
              } # end of zip_code
            }, # end of address
            # 21F. DATE STEPCHILD LEFT VETERAN'S HOUSEHOLD (MM-DD-YYYY)
            'living_expenses_paid' => {
              'more_than_half' => { key: 'step_children.living_expenses_paid.more_than_half[%iterator%]' },
              'half' => { key: 'step_children.living_expenses_paid.half[%iterator%]' },
              'less_than_half' => { key: 'step_children.living_expenses_paid.less_than_half[%iterator%]' }
            } # end of living_expenses_paid
          }, # end of step_children
          # -----------------  SECTION VI: VETERAN/CLAIMANT REPORTING DEATH OF A DEPENDENT  ----------------- #
          'deaths' => {
            limit: 2,
            first_key: 'full_name',
            'dependent_type' => {
              'spouse' => { key: 'deaths.dependent_type.spouse[%iterator%]' },
              'minor_child' => { key: 'deaths.dependent_type.minor_child[%iterator%]' },
              'stepchild' => { key: 'deaths.dependent_type.stepchild[%iterator%]' },
              'adopted' => { key: 'deaths.dependent_type.adopted[%iterator%]' },
              'dependent_parent' => { key: 'deaths.dependent_type.dependent_parent[%iterator%]' },
              'child_incapable_self_support' => {
                key: 'deaths.dependent_type.child_incapable_self_support[%iterator%]'
              },
              '18_23_years_old_in_school' => { key: 'deaths.dependent_type.18_23_years_old_in_school[%iterator%]' }
            },
            'full_name' => {
              'first' => {
                key: 'deaths.full_name.first[%iterator%]',
                limit: 12,
                question_num: 22,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO REPORT DEPEDENT DEATH > NAME > FIRST'
              },
              'middleInitial' => {
                key: 'deaths.full_name.middleInitial[%iterator%]',
                limit: 1,
                question_num: 22,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO REPORT DEPEDENT DEATH > NAME > MIDDLE INITIAL'
              },
              'last' => {
                key: 'deaths.full_name.last[%iterator%]',
                limit: 18,
                question_num: 22,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO REPORT DEPEDENT DEATH > NAME > LAST'
              }
              # @TODO 'suffix' =>  FE has suffix but no place for it on PDF
            }, # end of full name
            'dependent_death_date' => {
              'month' => {
                key: 'deaths.date.month[%iterator%]',
                limit: 2,
                question_num: 22,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO REPORT DEPEDENT DEATH > DATE > MONTH'
              },
              'day' => {
                key: 'deaths.date.day[%iterator%]',
                limit: 2,
                question_num: 22,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO REPORT DEPEDENT DEATH > DATE > DAY'
              },
              'year' => {
                key: 'deaths.date.year[%iterator%]',
                limit: 4,
                question_num: 22,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO REPORT DEPEDENT DEATH > DATE > YEAR'
              }
            }, # end of date of death
            'dependent_death_location' => {
              'location' => {
                'city' => {
                  key: 'deaths.location.city[%iterator%]',
                  limit: 18,
                  question_num: 22,
                  question_suffix: 'A',
                  question_text: 'INFORMATION NEEDED TO REPORT DEPEDENT DEATH > PLACE > CITY'
                },
                'state' => {
                  key: 'deaths.location.state[%iterator%]',
                  limit: 2,
                  question_num: 22,
                  question_suffix: 'B',
                  question_text: 'INFORMATION NEEDED TO REPORT DEPEDENT DEATH > PLACE > STATE'
                },
                'country' => {
                  key: 'deaths.location.country[%iterator%]',
                  limit: 2,
                  question_num: 22,
                  question_suffix: 'C',
                  question_text: 'INFORMATION NEEDED TO REPORT DEPEDENT DEATH > PLACE > COUNTRY'
                }
              }
            } # end dependent_death_location
          }, # end of deaths
          # -----------------  SECTION VII: VETERAN/CLAIMANT REPORTING MARRIAGE OF CHILD  ----------------- #
          'child_marriage' => {
            limit: 1,
            'full_name' => {
              'first' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].CHILDFirstName[30]',
                limit: 12,
                question_num: 23,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO REPORT MARRIAGE OF A CHILD > NAME > FIRST'
              }, # end of first name of married child
              'middleInitial' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].CHILDMIDDLEName[0]',
                limit: 1,
                question_num: 23,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO REPORT MARRIAGE OF A CHILD > NAME > MIDDLE INITIAL'
              }, # end of middle initial name of married child
              'last' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].CHILDLASTName[0]',
                limit: 18,
                question_num: 23,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO REPORT MARRIAGE OF A CHILD > NAME > LAST'
              }
              # @TODO 'suffix' =>  FE has suffix but no place for it on PDF
            }, # end full_name
            'date_married' => {
              'month' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].DateOfMarriage_Month[0]',
                limit: 2,
                question_num: 23,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO REPORT MARRIAGE OF CHILD > DATE > MONTH'
              },
              'day' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].DateOfMarriage_Day[0]',
                limit: 2,
                question_num: 23,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO REPORT MARRIAGE OF CHILD > DATE > DAY'
              },
              'year' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].DateOfMarriage_Year[0]',
                limit: 4,
                question_num: 23,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO REPORT MARRIAGE OF CHILD > DATE > YEAR'
              }
            } # end date_married
          }, # end of child marriage
          # ---  SECTION VIII: VETERAN/CLAIMANT REPORTING A SCHOOLCHILD OVER 18 HAS STOPPED ATTENDING SCHOOL  --- #
          'child_stopped_attending_school' => {
            limit: 1,
            'full_name' => {
              'first' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].NAMEOFSCHOOLCHILDFirstName[0]',
                limit: 12,
                question_num: 24,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO REPORT CHILD STOPPED ATTENDING SCHOOL > NAME > FIRST'
              },
              'middleInitial' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].NAMEOFSCHOOLCHILDMIDDLEName[0]',
                limit: 1,
                question_num: 24,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO REPORT CHILD STOPPED ATTENDING SCHOOL > NAME > MIDDLE INITIAL'
              },
              'last' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].NAMEOFSCHOOLCHILDLASTName[0]',
                limit: 18,
                question_num: 24,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO REPORT CHILD STOPPED ATTENDING SCHOOL > NAME > LAST'
              }
              # @TODO 'suffix' =>  FE has suffix but no place for it on PDF
            },
            'date_child_left_school' => {
              'month' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].DateSchoochildStoppedAttendingSchool_Month[0]',
                limit: 2,
                question_num: 24,
                question_suffix: 'A',
                question_text: 'INFORMATION NEEDED TO REPORT CHILD STOPPED ATTENDING SCHOOL > DATE > MONTH'
              },
              'day' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].DateSchoolchildStoppedAttendingSchool_Day[0]',
                limit: 2,
                question_num: 24,
                question_suffix: 'B',
                question_text: 'INFORMATION NEEDED TO REPORT CHILD STOPPED ATTENDING SCHOOL > DATE > DAY'
              },
              'year' => {
                key: 'form1[0].#subform[28].#subform[29].#subform[30].DateSchoolchildStoppedAttendingSshool_Year[0]',
                limit: 4,
                question_num: 24,
                question_suffix: 'C',
                question_text: 'INFORMATION NEEDED TO REPORT CHILD STOPPED ATTENDING SCHOOL > DATE > YEAR'
              }
            } # end date_child_left_school
          } # end child_stopped_attending_school
        }, # end dependents_application
        # -----------------  SECTION IX: REMARKS  ----------------- #
        'remarks' => {
          'remarks_line1' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[0]',
            limit: 35,
            question_num: 25,
            question_suffix: 'A',
            question_text: 'REMARKS'
          },
          'remarks_line2' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[1]',
            limit: 35,
            question_num: 25,
            question_suffix: 'B',
            question_text: 'REMARKS'
          },
          'remarks_line3' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[2]',
            limit: 35,
            question_num: 25,
            question_suffix: 'C',
            question_text: 'REMARKS'
          },
          'remarks_line4' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[3]',
            limit: 35,
            question_num: 25,
            question_suffix: 'D',
            question_text: 'REMARKS'
          },
          'remarks_line5' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[4]',
            limit: 35,
            question_num: 25,
            question_suffix: 'E',
            question_text: 'REMARKS'
          },
          'remarks_line6' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[5]',
            limit: 35,
            question_num: 25,
            question_suffix: 'F',
            question_text: 'REMARKS'
          },
          'remarks_line7' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[6]',
            limit: 35,
            question_num: 25,
            question_suffix: 'G',
            question_text: 'REMARKS'
          },
          'remarks_line8' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[7]',
            limit: 35,
            question_num: 25,
            question_suffix: 'H',
            question_text: 'REMARKS'
          },
          'remarks_line9' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[8]',
            limit: 35,
            question_num: 25,
            question_suffix: 'I',
            question_text: 'REMARKS'
          },
          'remarks_line10' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[9]',
            limit: 35,
            question_num: 25,
            question_suffix: 'J',
            question_text: 'REMARKS'
          },
          'remarks_line11' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[10]',
            limit: 35,
            question_num: 25,
            question_suffix: 'K',
            question_text: 'REMARKS'
          },
          'remarks_line12' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].Remarks[11]',
            limit: 35,
            question_num: 25,
            question_suffix: 'L',
            question_text: 'REMARKS'
          }
          # @TODO remarks
        },
        'addendum' => { key: 'addendum' },
        'veteran_ssn' => {
          'ssn1' => {
            'first' => { key: 'form1[0].#subform[18].Veterans_SocialSecurityNumber_FirstThreeNumbers[1]' },
            'second' => { key: 'form1[0].#subform[18].Veterans_SocialSecurityNumber_SecondTwoNumbers[1]' },
            'third' => { key: 'form1[0].#subform[18].Veterans_SocialSecurityNumber_LastFourNumbers[1]' }
          },
          'ssn2' => {
            'first' => { key: 'form1[0].#subform[19].#subform[20].Veterans_SocialSecurityNumber_FirstThreeNumbers[2]' },
            'second' => { key: 'form1[0].#subform[19].#subform[20].Veterans_SocialSecurityNumber_SecondTwoNumbers[2]' },
            'third' => { key: 'form1[0].#subform[19].#subform[20].Veterans_SocialSecurityNumber_LastFourNumbers[2]' }
          },
          'ssn3' => {
            'first' => { key: 'form1[0].#subform[21].#subform[22].Veterans_SocialSecurityNumber_FirstThreeNumbers[3]' },
            'second' => { key: 'form1[0].#subform[21].#subform[22].Veterans_SocialSecurityNumber_SecondTwoNumbers[3]' },
            'third' => { key: 'form1[0].#subform[21].#subform[22].Veterans_SocialSecurityNumber_LastFourNumbers[3]' }
          },
          'ssn4' => {
            'first' => { key: 'form1[0].#subform[23].#subform[24].Veterans_SocialSecurityNumber_FirstThreeNumbers[4]' },
            'second' => { key: 'form1[0].#subform[23].#subform[24].Veterans_SocialSecurityNumber_SecondTwoNumbers[4]' },
            'third' => { key: 'form1[0].#subform[23].#subform[24].Veterans_SocialSecurityNumber_LastFourNumbers[4]' }
          },
          'ssn5' => {
            'first' => {
              key: 'form1[0].#subform[25].#subform[26].#subform[27].Veterans_SocialSecurityNumber_FirstThreeNumbers[5]'
            },
            'second' => {
              key: 'form1[0].#subform[25].#subform[26].#subform[27].Veterans_SocialSecurityNumber_SecondTwoNumbers[5]'
            },
            'third' => {
              key: 'form1[0].#subform[25].#subform[26].#subform[27].Veterans_SocialSecurityNumber_LastFourNumbers[5]'
            }
          },
          'ssn6' => {
            'first' => {
              key: 'form1[0].#subform[28].#subform[29].#subform[30].Veterans_SocialSecurityNumber_FirstThreeNumbers[6]'
            },
            'second' => {
              key: 'form1[0].#subform[28].#subform[29].#subform[30].Veterans_SocialSecurityNumber_SecondTwoNumbers[6]'
            },
            'third' => {
              key: 'form1[0].#subform[28].#subform[29].#subform[30].Veterans_SocialSecurityNumber_LastFourNumbers[6]'
            }
          },
          'ssn7' => {
            'first' => {
              key: 'form1[0].#subform[31].#subform[32].#subform[33].Veterans_SocialSecurityNumber_FirstThreeNumbers[7]'
            },
            'second' => {
              key: 'form1[0].#subform[31].#subform[32].#subform[33].Veterans_SocialSecurityNumber_SecondTwoNumbers[7]'
            },
            'third' => {
              key: 'form1[0].#subform[31].#subform[32].#subform[33].Veterans_SocialSecurityNumber_LastFourNumbers[7]'
            }
          },
          'ssn8' => {
            'first' => {
              key: 'form1[0].#subform[34].#subform[35].Veterans_SocialSecurityNumber_FirstThreeNumbers[8]'
            },
            'second' => {
              key: 'form1[0].#subform[34].#subform[35].Veterans_SocialSecurityNumber_SecondTwoNumbers[8]'
            },
            'third' => {
              key: 'form1[0].#subform[34].#subform[35].Veterans_SocialSecurityNumber_LastFourNumbers[8]'
            }
          }
        }, # end veteran_ssn
        'signature' => {
          key: 'signature'
        },
        'signature_date' => {
          'month' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].DateMM[0]'
          },
          'day' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].DateDD[0]'
          },
          'year' => {
            key: 'form1[0].#subform[31].#subform[32].#subform[33].DateYYYY[0]'
          }
        } # end signature_date
      }.freeze

      def merge_fields(options = {})
        merge_addendum_helpers

        merge_veteran_helpers
        merge_spouse_helpers

        merge_previous_marriage_helpers
        merge_spouse_marriage_history_helpers
        merge_child_helpers

        merge_divorce_helpers
        merge_stepchildren_helpers

        merge_death_helpers
        merge_child_marriage_helpers
        merge_child_stopped_attending_school_helpers
        created_at = options[:created_at] if options[:created_at].present?
        expand_signature(@form_data['veteran_information']['full_name'], created_at&.to_date || Time.zone.today)
        @form_data['signature_date'] = split_date(@form_data['signatureDate'])

        expand_remarks
        expand_veteran_ssn

        @form_data
      end

      private

      def merge_veteran_helpers
        unless @form_data['veteran_information']
          @form_data['veteran_information'] = @form_data.dig('dependents_application', 'veteran_information')
        end

        # We add the user data to the form data in some jobs. It should always be present here.
        raise Dependents::ErrorClasses::MissingVeteranInfoError unless @form_data['veteran_information']

        veteran_information = @form_data['veteran_information']

        veteran_contact_information = @form_data['dependents_application']['veteran_contact_information']

        # extract middle initial
        veteran_information['full_name'] = extract_middle_i(veteran_information, 'full_name')

        # extract birth date
        veteran_information['birth_date'] = split_date(veteran_information['birth_date'])

        # extract ssn
        ssn = veteran_information['ssn']
        veteran_information['ssn'] = split_ssn(ssn.delete('-')) if ssn.present?

        expand_phone_number(veteran_contact_information)

        # extract postal code and country
        zip_code = split_postal_code(veteran_contact_information['veteran_address'])
        veteran_country = extract_country(veteran_contact_information['veteran_address'])
        electronic_correspondence = select_checkbox(veteran_contact_information['electronic_correspondence'])

        veteran_contact_information['veteran_address']['zip_code'] = zip_code
        veteran_contact_information['veteran_address']['country_name'] = veteran_country
        veteran_contact_information['electronic_correspondence'] = electronic_correspondence
      end

      def merge_spouse_helpers
        spouse = @form_data['dependents_application']['spouse_information']
        return if spouse.blank?

        # extract middle initial
        spouse['full_name'] = extract_middle_i(spouse, 'full_name')

        # extract birth date
        spouse['birth_date'] = split_date(spouse['birth_date'])

        # extract ssn
        spouse['ssn'] = split_ssn(spouse['ssn'].delete('-')) if spouse['ssn'].present?

        # extract postal code and country
        if @form_data['dependents_application']['does_live_with_spouse']['address'].present?
          @form_data['dependents_application']['does_live_with_spouse']['address']['postal_code'] =
            split_postal_code(@form_data.dig('dependents_application', 'does_live_with_spouse', 'address'))
          @form_data['dependents_application']['does_live_with_spouse']['address']['country_name'] =
            extract_country(@form_data.dig('dependents_application', 'does_live_with_spouse', 'address'))
        end

        # expand is_veteran
        is_veteran = @form_data.dig('dependents_application', 'spouse_information', 'is_veteran')
        @form_data['dependents_application']['spouse_information']['is_veteran'] = {
          'is_veteran_yes' => select_radio_button(is_veteran),
          'is_veteran_no' => select_radio_button(!is_veteran)
        }

        expand_marriage_info
        expand_does_live_with_spouse
      end

      def merge_previous_marriage_helpers
        previous_spouses = @form_data['dependents_application']['veteran_marriage_history']
        return if previous_spouses.blank?

        previous_spouses.each do |spouse|
          # extract middle initial
          spouse['full_name'] = extract_middle_i(spouse, 'full_name')

          # extract veteran marriage history dates
          spouse['start_date'] = split_date(spouse['start_date'])
          spouse['end_date'] = split_date(spouse['end_date'])

          reason_marriage_ended = spouse['reason_marriage_ended']
          # @TODO why is annulment not an option on FE ('Annulment or other')
          spouse['reason_marriage_ended'] = {
            'death' => select_radio_button(reason_marriage_ended == 'Death'),
            'divorce' => select_radio_button(reason_marriage_ended == 'Divorce'),
            # 'annulment' => select_radio_button(reason_marriage_ended == 'ANNULMENT'),
            'other' => select_radio_button(reason_marriage_ended == 'Other')
          }

          # extract country: FE uses 3 char country codes, but pdf expects 2 char country code
          spouse['start_location']['country'] = extract_country(spouse['start_location'])
          spouse['end_location']['country'] = extract_country(spouse['end_location'])
        end
      end

      def merge_spouse_marriage_history_helpers
        previous_spouses = @form_data['dependents_application']['spouse_marriage_history']
        return if previous_spouses.blank?

        previous_spouses.each do |spouse|
          # extract middle initial
          spouse['full_name'] = extract_middle_i(spouse, 'full_name')

          # extract spouse marriage history dates
          spouse['start_date'] = split_date(spouse['start_date'])
          spouse['end_date'] = split_date(spouse['end_date'])

          # expand reason marriage ended
          reason_marriage_ended = spouse['reason_marriage_ended']
          # @TODO why is annulment not an option on FE ('Annulment or other')
          spouse['reason_marriage_ended'] = {
            'death' => select_radio_button(reason_marriage_ended == 'Death'),
            'divorce' => select_radio_button(reason_marriage_ended == 'Divorce'),
            # 'annulment' => select_radio_button(reason_marriage_ended == 'ANNULMENT'),
            'other' => select_radio_button(reason_marriage_ended == 'Other')
          }

          # extract country: FE uses 3 char country codes, but pdf expects 2 char country code
          spouse['start_location']['country'] = extract_country(spouse['start_location'])
          spouse['end_location']['country'] = extract_country(spouse['end_location'])
        end
      end

      def merge_child_helpers
        children_to_add = @form_data['dependents_application']['children_to_add']
        return if children_to_add.blank?

        children_to_add.each do |child|
          # extract middle initial
          child['full_name'] = extract_middle_i(child, 'full_name')

          # extract birth date
          child['birth_date'] = split_date(child['birth_date'])

          # extract ssn
          child['ssn'] = split_ssn(child['ssn'].delete('-')) if child['ssn'].present?

          # extract country: FE uses 3 char country codes, but pdf expects 2 char country code
          if child['birth_location'].present?
            child['birth_location']['location']['country'] = extract_country(child['birth_location']['location'])
          end

          # extract postal code and country
          unless child['does_child_live_with_you']
            child['address']['postal_code'] =
              split_postal_code(child['address'])
            child['address']['country'] =
              extract_country(child['address'])
          end

          expand_child_status(child)
          expand_child_previously_married(child)
        end
      end

      # rubocop:disable Metrics/MethodLength
      def expand_child_status(child)
        # expand child status
        child_status = child['relationship_to_child'] || {}
        date_entered_household = split_date(child['date_entered_household'])

        if child.key?('has_child_ever_been_married')
          child['has_child_ever_been_married'] = select_radio_button(child['has_child_ever_been_married'])
        end

        # is_biological_child_of_spouse_no
        bcos_no = child['is_biological_child_of_spouse']

        child['is_biological_child_of_spouse'] = {
          'is_biological_child_of_spouse_yes' => select_radio_button(child['is_biological_child_of_spouse']),
          'is_biological_child_of_spouse_no' => bcos_no.nil? ? 'Off' : select_radio_button(!bcos_no)
        }

        child['school_age_in_school'] =
          child.key?('school_age_in_school') ? 'Off' : select_radio_button(child['school_age_in_school'])

        # @TODO 18-23 YEARS OLD AND IN SCHOOL
        child['relationship_to_child'] = {
          # 'school_age_in_school' => select_radio_button(child_status['school_age_in_school']),
          'adopted' => select_radio_button(child_status['adopted']),
          'stepchild' => select_radio_button(child_status['stepchild'])
        }
        child['date_entered_household'] = date_entered_household if date_entered_household.present?

        # is_biological_child
        bc = child['is_biological_child']
        # does_child_have_permanent_disability
        dchpd = child['does_child_have_permanent_disability']
        child['is_biological_child'] = bc.nil? ? 'Off' : select_radio_button(bc)
        child['does_child_have_permanent_disability'] = dchpd.nil? ? 'Off' : select_radio_button(dchpd)
      end
      # rubocop:enable Metrics/MethodLength

      def expand_child_previously_married(child)
        # return unless child['marriage_end_date'] == 'Yes'
        return if child['marriage_end_date'].blank?

        # extract date
        child['marriage_end_date'] = split_date(child['marriage_end_date'])

        # expand reason child marriage ended
        reason_marriage_ended = child['marriage_end_reason']
        if reason_marriage_ended.include?('Divorce') || reason_marriage_ended.include?('Death')
          # we show 'Divorce' and 'Death' as options on the FE as opposed to 'Declared Void'
          reason_marriage_ended = 'Declared Void'
        end
        child['marriage_end_reason'] = {
          'declared_void' => select_radio_button(reason_marriage_ended == 'Declared Void'),
          'annulled' => select_radio_button(reason_marriage_ended == 'Annulment'),
          'other' => select_radio_button(reason_marriage_ended == 'Other')
        }

        expand_other_reason_marriage_ended(child)
      end

      def expand_other_reason_marriage_ended(child)
        other_reason_marriage_ended = child['marriage_end_description']
        if other_reason_marriage_ended.present?
          child['marriage_end_description'] = {}
          if other_reason_marriage_ended.length > 8 && other_reason_marriage_ended.length < 16
            child['marriage_end_description']['reason_marriage_ended_other_line1'] =
              other_reason_marriage_ended[0..7]
            child['marriage_end_description']['reason_marriage_ended_other_line2'] =
              other_reason_marriage_ended[8..15]
          else
            child['marriage_end_description']['reason_marriage_ended_other_line1'] =
              other_reason_marriage_ended
          end
        end
      end

      def merge_divorce_helpers
        divorce = @form_data['dependents_application']['report_divorce']
        return if divorce.blank?

        # extract date
        divorce['date'] = split_date(divorce['date'])

        # extract middle initial
        divorce['full_name'] = extract_middle_i(divorce, 'full_name')

        # extract country: FE uses 3 char country codes, but pdf expects 2 char country code
        if divorce['divorce_location']['country'].present?
          divorce['divorce_location']['country'] = extract_country(divorce['divorce_location'])
        end
      end

      def merge_stepchildren_helpers
        step_children = @form_data['dependents_application']['step_children']
        return if step_children.blank?

        step_children.each do |stepchild|
          # extract middle initial
          stepchild['full_name'] = extract_middle_i(stepchild, 'full_name')
          stepchild['biological_stepchild'] = stepchild['full_name']
          stepchild['who_does_the_stepchild_live_with'] =
            extract_middle_i(stepchild, 'who_does_the_stepchild_live_with')

          # extract step_children zip codes
          if stepchild['address'].present?
            stepchild['address']['postal_code'] = split_postal_code(stepchild['address'])
            stepchild['address']['country'] = extract_country(stepchild['address'])
          end

          # expand living_expenses_paid
          living_expenses_paid = stepchild['living_expenses_paid']
          stepchild['living_expenses_paid'] = {
            'more_than_half' => select_radio_button(living_expenses_paid == 'More than half'),
            'half' => select_radio_button(living_expenses_paid == 'Half'),
            'less_than_half' => select_radio_button(living_expenses_paid == 'Less than half')
          }

          # if any stepchild is present then this should be checked as yes
          stepchild['biological_adopted_stepchild'] = {
            'biological_adopted_stepchild_yes' => select_radio_button(true),
            'biological_adopted_stepchild_no' => 'Off'
          }
        end

        # @TODO we ask this on our form for each child, the pdf only has this in one place
        # expand_supporting_stepchild
      end

      # rubocop:disable Metrics/MethodLength
      def merge_death_helpers
        deaths = @form_data['dependents_application']['deaths']
        return if deaths.blank?

        deaths.each do |death|
          # extract middle initial
          death['full_name'] = extract_middle_i(death, 'full_name')

          # extract date
          death['dependent_death_date'] = split_date(death['dependent_death_date'])

          # extract country: FE uses 3 char country codes, but pdf expects 2 char country code
          if death['dependent_death_location']['location']['country'].present?
            death['dependent_death_location']['location']['country'] =
              extract_country(death['dependent_death_location']['location'])
          end

          # expand dependent type
          dependent_type = death['dependent_type']
          if dependent_type == 'CHILD'
            # ex. "dependent_type":"CHILD","child_status":{"child_under18":true,"step_child":true}
            dependent_type = death['child_status']
          end
          death['dependent_type'] = {
            'spouse' => select_radio_button(dependent_type == 'SPOUSE'),
            'minor_child' => select_radio_button(dependent_type['child_under18']),
            'stepchild' => select_radio_button(dependent_type['step_child']),
            'adopted' => select_radio_button(dependent_type['adopted']),
            'dependent_parent' => select_radio_button(dependent_type == 'DEPENDENT_PARENT'),
            'child_incapable_self_support' => select_radio_button(dependent_type['disabled']),
            '18_23_years_old_in_school' => select_radio_button(dependent_type['child_over18_in_school'])
          }
        end
      end
      # rubocop:enable Metrics/MethodLength

      def merge_child_marriage_helpers
        child_marriages = @form_data['dependents_application']['child_marriage']
        return if child_marriages.blank?

        child_marriages.each do |child_marriage|
          # extract middle initial
          child_marriage['full_name'] = extract_middle_i(child_marriage, 'full_name')
          # extract date
          child_marriage['date_married'] = split_date(child_marriage['date_married'])
        end
      end

      def merge_child_stopped_attending_school_helpers
        children_stopped_attending_school = @form_data['dependents_application']['child_stopped_attending_school']
        return if children_stopped_attending_school.blank?

        children_stopped_attending_school.each do |child_stopped_attending_school|
          # extract middle initial
          child_stopped_attending_school['full_name'] = extract_middle_i(child_stopped_attending_school, 'full_name')

          # extract date
          child_stopped_attending_school['date_child_left_school'] =
            split_date(child_stopped_attending_school['date_child_left_school'])
        end
      end

      def expand_phone_number(veteran_contact_information)
        phone_number = veteran_contact_information['phone_number']
        if phone_number.present?
          phone_number = phone_number.delete('^0-9')
          veteran_contact_information['phone_number'] = {
            'phone_area_code' => phone_number[0..2],
            'phone_first_three_numbers' => phone_number[3..5],
            'phone_last_four_numbers' => phone_number[6..9]
          }
        end
      end

      def expand_marriage_info
        # extract marriage date
        @form_data['dependents_application']['current_marriage_information']['date'] =
          split_date(@form_data.dig('dependents_application', 'current_marriage_information', 'date'))

        marriage_type = @form_data.dig('dependents_application', 'current_marriage_information', 'type_of_marriage')
        @form_data['dependents_application']['current_marriage_information']['type_of_marriage'] = {
          'civil_ceremony' => select_radio_button(marriage_type == 'CIVIL'),
          'religious_ceremony' => select_radio_button(marriage_type == 'CEREMONIAL'),
          'common_law' => select_radio_button(marriage_type == 'COMMON-LAW'),
          'tribal' => select_radio_button(marriage_type == 'TRIBAL'),
          'proxy' => select_radio_button(marriage_type == 'PROXY'),
          'other' => select_radio_button(marriage_type == 'OTHER')
        }

        @form_data['dependents_application']['current_marriage_information']['location']['country'] =
          extract_country(@form_data.dig('dependents_application', 'current_marriage_information', 'location'))
      end

      def expand_does_live_with_spouse
        does_live_with_spouse =
          @form_data.dig('dependents_application', 'does_live_with_spouse', 'spouse_does_live_with_veteran')
        @form_data['dependents_application']['does_live_with_spouse']['spouse_does_live_with_veteran'] = {
          'spouse_does_live_with_veteran_yes' => select_radio_button(does_live_with_spouse),
          'spouse_does_live_with_veteran_no' => select_radio_button(!does_live_with_spouse)
        }
      end

      def expand_remarks
        @form_data['remarks'] = {}
        # @TODO FE changes for remarks
        # 12.times do |i|
        #   @form_data['remarks']['remarks_line' + (i + 1).to_s] = ""
        # end
      end

      def expand_veteran_ssn
        # veteran ssn is repeated at the top of 8 pages
        veteran_ssn = @form_data['veteran_information']['ssn']
        @form_data['veteran_ssn'] = {}
        8.times do |i|
          @form_data['veteran_ssn']["ssn#{i + 1}"] = veteran_ssn
        end
      end

      ##
      # Merges addendum text for household and dependent income questions
      #
      # @return [void]
      def merge_addendum_helpers
        pension_flipper = Flipper.enabled?(:va_dependents_net_worth_and_pension)
        addendum_text = add_household_income

        # income question when adding spouse
        spouse_name = combine_full_name(@form_data.dig('dependents_application', 'spouse_information', 'full_name'))
        spouse_income = @form_data.dig('dependents_application', 'does_live_with_spouse', 'spouse_income')
        spouse_income_exists = @form_data.dig('dependents_application', 'does_live_with_spouse')&.key?('spouse_income')
        # Question will only be asked if va_dependents_net_worth_and_pension FF is off
        # OR if FF is on and veteran receives pension benefits
        unless pension_flipper && !spouse_income_exists
          addendum_text += add_dependent_income(spouse_name, spouse_income)
        end

        # income questions when adding children
        children_to_add = @form_data.dig('dependents_application', 'children_to_add')
        addendum_text += add_dependents(children_to_add, 'income_in_last_year')

        # income question when reporting a divorce
        # Question will only be asked if va_dependents_net_worth_and_pension FF is off
        unless pension_flipper
          spouse_name = combine_full_name(@form_data.dig('dependents_application', 'report_divorce', 'full_name'))
          spouse_income = @form_data.dig('dependents_application', 'report_divorce', 'spouse_income')
          addendum_text += add_dependent_income(spouse_name, spouse_income)
        end

        # income questions when reporting deaths
        # Question will only be asked if va_dependents_net_worth_and_pension FF is off
        unless pension_flipper
          deaths = @form_data.dig('dependents_application', 'deaths')
          addendum_text += add_dependents(deaths, 'deceased_dependent_income')
        end

        @form_data['addendum'] = addendum_text
      end

      ##
      # Generates addendum text for household income question
      #
      # @return [String] Formatted household income question with answer
      def add_household_income
        net_worth = @form_data.dig('dependents_application', 'household_income')

        # If va_dependents_net_worth_and_pension FF is off, show "greater than" wording
        # If on, show "less than" wording (reversed logic for UI versus RBPS value)
        # Question will only be asked if va_dependents_net_worth_and_pension FF is off
        # OR if FF is on and veteran receives pension benefits
        if Flipper.enabled?(:va_dependents_net_worth_and_pension)
          return '' unless @form_data['dependents_application']&.key?('household_income')

          "Did the household have a net worth less than $163,699 in the last tax year? #{format_boolean(!net_worth)}"
        else
          "Did the household have a net worth greater than $163,699 in the last tax year? #{format_boolean(net_worth)}"
        end
      end

      ##
      # Generates addendum text for a dependent's income question
      #
      # @param dependent_name [String] Full name of the dependent
      # @param dependent_income [Boolean] Whether dependent had income
      # @return [String] Formatted income question with answer, or empty string if no name
      def add_dependent_income(dependent_name, dependent_income)
        return '' if dependent_name.blank?

        "\n\nDid #{dependent_name} have an income in the last 365 days? #{format_radio_yes_no(dependent_income)}"
      end

      ##
      # Generates addendum text for multiple dependents' income questions
      #
      # @param dependents_hash [Array<Hash>] Array of dependent hashes
      # @param income_attr [String] Name of income attribute to check
      # @return [String] Combined income questions for all dependents, or empty string if none
      def add_dependents(dependents_hash, income_attr)
        return '' if dependents_hash.blank?
        # Question will only be asked if va_dependents_net_worth_and_pension FF is off
        # OR if FF is on and veteran receives pension benefits
        return '' if Flipper.enabled?(:va_dependents_net_worth_and_pension) && !dependents_hash.first&.key?(income_attr)

        dependent_text = ''
        dependents_hash.each do |dependent|
          dependent_name = combine_full_name(dependent['full_name'])
          dependent_income = dependent[income_attr]
          dependent_text += add_dependent_income(dependent_name, dependent_income)
        end

        dependent_text
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
