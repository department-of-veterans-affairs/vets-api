# frozen_string_literal: true

module PdfFill
  module Forms
    module FieldMappings
      class Va21p530a
        KEY = {
          # SECTION 1: VETERAN'S IDENTIFICATION INFORMATION
          'veteranInformation' => {
            'fullName' => {
              'first' => {
                key: 'VBA21535[0].#subform[0].Name_Of_Deceased_Veteran_First_Name[0]',
                limit: 12,
                question_num: 1,
                question_text: 'Name of Deceased Veteran - First Name'
              },
              'middle' => {
                key: 'VBA21535[0].#subform[0].Deceased_Veteran_Middle_Initial1[0]',
                limit: 1,
                question_num: 1,
                question_text: 'Name of Deceased Veteran - Middle Initial'
              },
              'last' => {
                key: 'VBA21535[0].#subform[0].Deceased_Veteran_Last_Name[0]',
                limit: 18,
                question_num: 1,
                question_text: 'Name of Deceased Veteran - Last Name'
              }
            },
            'ssn' => {
              'first' => {
                key: 'VBA21535[0].#subform[0].Veterans_Social_Security_Number_FirstThreeNumbers[0]',
                limit: 3,
                question_num: 2,
                question_text: 'Veteran\'s Social Security Number - First Three'
              },
              'second' => {
                key: 'VBA21535[0].#subform[0].Deceased_Veterans_Social_Security_Number_SecondTwoNumbers[0]',
                limit: 2,
                question_num: 2,
                question_text: 'Veteran\'s Social Security Number - Middle Two'
              },
              'third' => {
                key: 'VBA21535[0].#subform[0].Deceased_Veterans_Social_Security_Number_LastFourNumbers[0]',
                limit: 4,
                question_num: 2,
                question_text: 'Veteran\'s Social Security Number - Last Four'
              }
            },
            'ssnPage2' => {
              'first' => {
                key: 'VBA21535[0].#subform[1].Veterans_Social_Security_Number_FirstThreeNumbers[1]',
                limit: 3
              },
              'second' => {
                key: 'VBA21535[0].#subform[1].Deceased_Veterans_Social_Security_Number_SecondTwoNumbers[1]',
                limit: 2
              },
              'third' => {
                key: 'VBA21535[0].#subform[1].Deceased_Veterans_Social_Security_Number_LastFourNumbers[1]',
                limit: 4
              }
            },
            'vaServiceNumber' => {
              key: 'VBA21535[0].#subform[0].Veterans_Service_Number[0]',
              question_num: 3,
              question_text: 'Veteran\'s Service Number (If different from Item 2)'
            },
            'vaFileNumber' => {
              key: 'VBA21535[0].#subform[0].Veterans_File_Number[0]',
              question_num: 4,
              question_text: 'Veteran\'s File Number'
            },
            'dateOfBirth' => {
              'month' => {
                key: 'VBA21535[0].#subform[0].DOB_Month[0]',
                limit: 2,
                question_num: 5,
                question_text: 'Veteran\'s Date of Birth - Month'
              },
              'day' => {
                key: 'VBA21535[0].#subform[0].DOB_Day[0]',
                limit: 2,
                question_num: 5,
                question_text: 'Veteran\'s Date of Birth - Day'
              },
              'year' => {
                key: 'VBA21535[0].#subform[0].DOB_Year[0]',
                limit: 4,
                question_num: 5,
                question_text: 'Veteran\'s Date of Birth - Year'
              }
            },
            'placeOfBirth' => {
              key: 'VBA21535[0].#subform[0].Veterans_Place_Of_Birth[0]',
              question_num: 6,
              limit: 60,
              question_text: 'Veteran\'s Place of Birth (City and State)'
            },
            'dateOfDeath' => {
              'month' => {
                key: 'VBA21535[0].#subform[0].Veterans_Date_Of_Death_Month[0]',
                limit: 2,
                question_num: 7,
                question_text: 'Veteran\'s Date of Death - Month'
              },
              'day' => {
                key: 'VBA21535[0].#subform[0].Date_Of_Death_Day[0]',
                limit: 2,
                question_num: 7,
                question_text: 'Veteran\'s Date of Death - Day'
              },
              'year' => {
                key: 'VBA21535[0].#subform[0].Date_Of_Death_Year[0]',
                limit: 4,
                question_num: 7,
                question_text: 'Veteran\'s Date of Death - Year'
              }
            }
          },

          # SECTION 2: VETERAN'S ACTIVE DUTY SERVICE
          'veteranServicePeriods' => {
            'periods' => {
              limit: 3,
              question_num: 8,
              question_text: 'Veteran\'s Active Duty Service',
              'serviceBranch' => {
                key: 'VBA21535[0].#subform[0].Branch_Of_Service[%iterator%]',
                question_num: 8,
                question_text: 'Branch of Service'
              },
              'dateEnteredService' => {
                key: 'VBA21535[0].#subform[0].DATE_ENTERED_SERVICE[%iterator%]',
                question_num: 8,
                question_text: 'Date Entered Service'
              },
              'placeEnteredService' => {
                key: 'VBA21535[0].#subform[0].PLACE_ENTERED_SERVICE[%iterator%]',
                question_num: 8,
                limit: 40,
                question_text: 'Place Entered Service'
              },
              'rankAtSeparation' => {
                key: 'VBA21535[0].#subform[0].GRADE_RANK_OR_RATING_WHEN_SEPARATED_FROM_SERVICE[%iterator%]',
                question_num: 9,
                limit: 70,
                question_text: 'Grade, Rank or Rating When Separated'
              },
              'dateLeftService' => {
                key: 'VBA21535[0].#subform[0].DATE_LEFT_ACTIVE_SERVICE[%iterator%]',
                question_num: 9,
                question_text: 'Date Left Active Service'
              },
              'placeLeftService' => {
                key: 'VBA21535[0].#subform[0].PLACE_LEFT_ACTIVE_SERVICE[%iterator%]',
                question_num: 9,
                limit: 40,
                question_text: 'Place Left Active Service'
              }
            },
            'servedUnderDifferentName' => {
              key: 'VBA21535[0].#subform[0].' \
                   'If-Veteran_Served_Under_Name_Other_Than_That_Shown_In_Item_1_' \
                   'Give_Full_Name_And_Service_Renedered_Under_That_Name[0]',
              question_num: 10,
              limit: 125,
              question_text: 'If Veteran Served Under Name Other than that Shown in Item 1'
            }
          },

          # SECTION 3: RECIPIENT ORGANIZATION INFORMATION
          'burialInformation' => {
            'nameOfStateCemeteryOrTribalOrganization' => {
              key: 'VBA21535[0].#subform[0].Name_Of_State_Claiming_Internment_Allowance[0]',
              question_num: 11,
              limit: 75,
              question_text: 'Name of State Claiming Internment Allowance'
            },
            'placeOfBurial' => {
              'stateCemeteryOrTribalCemeteryName' => {
                key: 'VBA21535[0].#subform[0].STATE_CEMETERY_NAME[0]',
                question_num: 12,
                limit: 65,
                question_text: 'State Cemetery Name'
              },
              'stateCemeteryOrTribalCemeteryLocation' => {
                key: 'VBA21535[0].#subform[0].STATE_CEMETERY_LOCATION[0]',
                question_num: 12,
                limit: 85,
                question_text: 'State Cemetery Location'
              }
            },
            'dateOfBurial' => {
              key: 'VBA21535[0].#subform[0].DATE_OF_BURIAL_MM_DD_YYYY[0]',
              question_num: 13,
              question_text: 'Date of Burial (MM/DD/YYYY)'
            },
            'recipientOrganization' => {
              'name' => {
                key: 'VBA21535[0].#subform[0].RECIPIENT_ORGANIZATION_NAME_FULL_NAME_OF_PAYEE[0]',
                question_num: 14,
                limit: 50,
                question_text: 'Recipient Organization Name (Full Name of Payee)'
              },
              'phoneNumber' => {
                key: 'VBA21535[0].#subform[0].RECIPIENT_ORGANIZATION_PHONE_NUMBER_Include_Area_Code[0]',
                question_num: 15,
                limit: 40,
                question_text: 'Recipient Organization Phone Number (Include Area Code)'
              },
              'address' => {
                'streetAndNumber' => {
                  key: 'VBA21535[0].#subform[0].Recipient_Organization_Payee_Address_NumberAndStreet[0]',
                  limit: 30,
                  question_num: 16,
                  question_text: 'Address - Number and Street'
                },
                'aptOrUnitNumber' => {
                  key: 'VBA21535[0].#subform[0].MailingAddress_ApartmentOrUnitNumber[0]',
                  limit: 5,
                  question_num: 16,
                  question_text: 'Address - Apartment or Unit Number'
                },
                'city' => {
                  key: 'VBA21535[0].#subform[0].MailingAddress_City[0]',
                  limit: 18,
                  question_num: 16,
                  question_text: 'Address - City'
                },
                'state' => {
                  key: 'VBA21535[0].#subform[0].Mailing_Address_State_Or_Province[0]',
                  limit: 2,
                  question_num: 16,
                  question_text: 'Address - State'
                },
                'country' => {
                  key: 'VBA21535[0].#subform[0].Mailing_Address_Country[0]',
                  limit: 2,
                  question_num: 16,
                  question_text: 'Address - Country'
                },
                'postalCode' => {
                  key: 'VBA21535[0].#subform[0].Mailing_Address_ZIP_Or_Postal_Code_First_Five_Numbers[0]',
                  limit: 5,
                  question_num: 16,
                  question_text: 'Address - ZIP Code (First Five)'
                },
                'postalCodeExtension' => {
                  key: 'VBA21535[0].#subform[0].Mailing_Address_ZIP_Or_Postal_Code_Last_Four_Numbers[0]',
                  limit: 4,
                  question_num: 16,
                  question_text: 'Address - ZIP+4 Extension'
                }
              }
            }
          },

          # CERTIFICATION
          'certification' => {
            'titleOfStateOrTribalOfficial' => {
              key: 'VBA21535[0].#subform[1].' \
                   'Title_Of_State_Or_Tribal_Official_Delegated_Responsibility_To_Apply_For_Federal_Funds[0]',
              question_text: 'Title of State or Tribal Official',
              limit: 90,
              question_num: 17
            },
            'dateSigned' => {
              key: 'VBA21535[0].#subform[1].DATE_SIGNED[0]',
              question_text: 'Date Signed (MM/DD/YYYY)'
            }
            # NOTE: 'signature' field is not mapped here - it's stamped onto the PDF via stamp_signature method
          },

          # REMARKS
          'remarks' => {
            key: 'VBA21535[0].#subform[1].Remarks[0]',
            question_text: 'Remarks',
            question_num: 18,
            limit: 2000
          }
        }.freeze
      end
    end
  end
end
