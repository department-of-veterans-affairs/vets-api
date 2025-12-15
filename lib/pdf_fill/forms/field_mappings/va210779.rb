# frozen_string_literal: true

module PdfFill
  module Forms
    module FieldMappings
      class Va210779
        KEY = {
          veteranInformation: {
            fullName: {
              first: {
                key: 'F[0].Page_1[0].Veterans_First_Name[0]',
                question_text: "1. VETERAN'S NAME Enter First Name.",
                type: 'Text'
              },
              middle: {
                key: 'F[0].Page_1[0].Veterans_Middle_Initial[0]',
                question_text: "1. Veteran's Name. Enter Middle Initial.",
                type: 'Text'
              },
              last: {
                key: 'F[0].Page_1[0].Veterans_Last_Name[0]',
                question_text: "1. Veteran's Name. Enter Last Name.",
                type: 'Text'
              }
            },
            dateOfBirth: {
              month: {
                key: 'F[0].Page_1[0].Date_Of_Birth_Month[0]',
                question_text: '4. Date of Birth. Enter 2 digit Month.  ',
                type: 'Text'
              },
              day: {
                key: 'F[0].Page_1[0].Date_Of_Birth_Day[0]',
                question_text: '4. Date of Birth. Enter 2 digit day.',
                type: 'Text'
              },
              year: {
                key: 'F[0].Page_1[0].Date_Of_Birth_Year[0]',
                question_text: '4. Date of Birth. Enter 4 digit year.',
                type: 'Text'
              }
            },
            veteranId: {
              ssn: {
                first: {
                  key: 'F[0].Page_1[0].Social_Security_Number_FirstThreeNumbers[0]',
                  question_text: '2. Social Security Number. Enter First Three Digits.',
                  type: 'Text'
                },
                second: {
                  key: 'F[0].Page_1[0].Social_Security_Number_SecondTwoNumbers[0]',
                  question_text: '2. Social Security Number. Enter middle 2 digits.',
                  type: 'Text'
                },
                third: {
                  key: 'F[0].Page_1[0].Social_Security_Number_LastFourNumbers[0]',
                  question_text: '2. Social Security Number. Enter Last Four Digits.',
                  type: 'Text'
                }
              },
              vaFileNumber: {
                key: 'F[0].Page_1[0].VA_File_Number[0]',
                question_text: '3. V. A. File Number ',
                type: 'Text'
              }
            }
          },
          claimantInformation: {
            fullName: {
              first: {
                key: 'F[0].Page_1[0].Claimants_First_Name[0]',
                question_text: "5. Claimant's Name. Enter First Name.",
                type: 'Text'
              },
              middle: {
                key: 'F[0].Page_1[0].Claimants_Middle_Initial[0]',
                question_text: "5. Claimant's Name. Enter Middle Initial.",
                type: 'Text'
              },
              last: {
                key: 'F[0].Page_1[0].Claimants_Last_Name[0]',
                question_text: "5. Claimant's Name. Enter Last Name.",
                type: 'Text'
              }
            },
            dateOfBirth: {
              month: {
                key: 'F[0].Page_1[0].Date_Of_Birth_Month[1]',
                question_text: "8. Claimant's Date of Birth. Enter 2 digit Month.  ",
                type: 'Text'
              },
              day: {
                key: 'F[0].Page_1[0].Date_Of_Birth_Day[1]',
                question_text: "8. Claimant's Date of Birth. Enter 2 digit day.",
                type: 'Text'
              },
              year: {
                key: 'F[0].Page_1[0].Date_Of_Birth_Year[1]',
                question_text: "8.  Claimant's Date of Birth. Enter 4 digit year.",
                type: 'Text'
              }
            },
            veteranId: {
              ssn: {
                first: {
                  key: 'F[0].Page_1[0].Claimants_Social_Security_Number_FirstThreeNumbers[0]',
                  question_text: '6. Claimant\'s Social Security Number. Enter First Three Digits.',
                  type: 'Text'
                },
                second: {
                  key: 'F[0].Page_1[0].Claimants_Social_Security_Number_SecondTwoNumbers[0]',
                  question_text: '6. Claimant\'s Social Security Number. Enter middle 2 digits.',
                  type: 'Text'
                },
                third: {
                  key: 'F[0].Page_1[0].Claimants_Social_Security_Number_LastFourNumbers[0]',
                  question_text: '6. Claimant\'s Social Security Number. Enter Last Four Digits.',
                  type: 'Text'
                }
              },
              vaFileNumber: {
                key: 'F[0].Page_1[0].Claimants_VA_File_Number_If_Applicable[0]',
                question_text: "7. Claimant's V. A. File Number (If applicable). ",
                type: 'Text'
              }
            }
          },
          nursingHomeInformation: {
            nursingHomeName: {
              key: 'F[0].Page_1[0].Name_Of_Nursing_Home[0]',
              question_text: '9. Name of Nursing Home.',
              type: 'Text'
            },
            nursingHomeAddress: {
              street: {
                key: 'F[0].Page_1[0].Address_Of_Nursing_Home_NumberAndStreet[0]',
                question_text: '10. Address of Nursing Home. Enter Number and Street.',
                type: 'Text'
              },
              street2: {
                key: 'F[0].Page_1[0].Apartment_Or_Unit_Number[0]',
                question_text: '10. Address of Nursing Home. Enter Apartment or Unit Number.',
                type: 'Text'
              },
              city: {
                key: 'F[0].Page_1[0].City[0]',
                question_text: '10. Address of Nursing Home. Enter City.',
                type: 'Text'
              },
              state: {
                key: 'F[0].Page_1[0].State_Or_Province[0]',
                question_text: '10. Address of Nursing Home. Enter State or Province.',
                type: 'Text'
              },
              country: {
                key: 'F[0].Page_1[0].Country[0]',
                question_text: '10. Address of Nursing Home. Enter Country.',
                type: 'Text'
              },
              postalCode: {
                firstFive: {
                  key: 'F[0].Page_1[0].ZIP_Or_Postal_Code_FirstFiveNumbers[0]',
                  question_text: '10. Address of Nursing Home. Enter ZIP or Postal Code. First 5 digits.',
                  type: 'Text'
                },
                lastFour: {
                  key: 'F[0].Page_1[0].ZIP_Or_Postal_Code_LastFourNumbers[0]',
                  question_text: '10. Address of Nursing Home. Enter ZIP or Postal Code. Enter last 4 digits.',
                  type: 'Text'
                }
              }
            }
          },
          generalInformation: {
            admissionDate: {
              month: {
                key: 'F[0].Page_1[0].Date_Admitted_Month[0]',
                question_text: '11. Date Admitted to Nursing Home. Enter 2 digit Month.  ',
                type: 'Text'
              },
              day: {
                key: 'F[0].Page_1[0].Date_Admitted_Day[0]',
                question_text: '11. Date Admitted to Nursing Home. Enter 2 digit day.',
                type: 'Text'
              },
              year: {
                key: 'F[0].Page_1[0].Date_Admitted_Year[0]',
                question_text: '11. Date Admitted to Nursing Home. Enter 4 digit year.',
                type: 'Text'
              }
            },
            medicaidFacility: {
              key: 'F[0].Page_1[0].RadioButtonList[1]',
              options: %w[
                1
                2
                Off
              ],
              type: 'Button'
            },
            medicaidApplication: {
              key: 'F[0].Page_1[0].RadioButtonList[3]',
              options: %w[
                1
                2b
                Off
              ],
              type: 'Button'
            },
            patientMedicaidCovered: {
              key: 'F[0].Page_1[0].RadioButtonList[2]',
              options: %w[
                1
                2
                Off
              ],
              type: 'Button'
            },
            medicaidStartDate: {
              month: {
                key: 'F[0].Page_1[0].Date_Medicaid_Began_Month[0]',
                question_text: '14. B. Date Medicaid Plan Began. Enter 2 digit Month.  ',
                type: 'Text'
              },
              day: {
                key: 'F[0].Page_1[0].Date__Medicaid_Began_Day[0]',
                question_text: '14. B. Date Medicaid Plan Began. Enter 2 digit day.',
                type: 'Text'
              },
              year: {
                key: 'F[0].Page_1[0].Date_Medicaid_Began_Year[0]',
                question_text: '14. B. Date Medicaid Plan Began. Enter 4 digit year.',
                type: 'Text'
              }
            },
            monthlyCosts: {
              thousands: {
                key: 'F[0].Page_1[0].Amount[1]',
                question_text: '15. MONTHLY AMOUNT PATIENT IS RESPONSIBLE FOR OUT OF POCKET.' \
                               ' Enter AMOUNT.  3 digits.',
                type: 'Text'
              },
              ones: {
                key: 'F[0].Page_1[0].Amount[0]',
                question_text: '15. Enter AMOUNT. Last 3 digits.',
                type: 'Text'
              },
              cents: {
                key: 'F[0].Page_1[0].Amount_Cents[0]',
                question_text: '15. Enter AMOUNT. 2 digit cents.',
                type: 'Text'
              }
            },
            certificationLevelOfCare: {
              key: 'F[0].Page_1[0].RadioButtonList[0]',
              options: %w[
                1
                2
                Off
              ],
              type: 'Button'
            },
            nursingOfficialName: {
              key: 'F[0].Page_1[0].Nursing_Home_Officials_Name[0]',
              question_text: '17. Nursing Home Official\'s Name (First and Last).',
              type: 'Text'
            },
            nursingOfficialTitle: {
              key: 'F[0].Page_1[0].Nursing_Home_Officials_Title[0]',
              question_text: '18. Nursing Home Official\'s Title.',
              type: 'Text'
            },
            nursingOfficialInternationalPhoneNumber: {
              key: 'F[0].Page_1[0].International_Telephone_Number_If_Applicable[0]',
              question_text: '19. Enter International Phone Number (If applicable).',
              type: 'Text'
            },
            nursingOfficialPhoneNumber: {
              phone_area_code: {
                key: 'F[0].Page_1[0].Nursing_Home_Officials_Phone_Number_Area_Code[0]',
                question_text: "19. NURSING HOME OFFICIAL'S OFFICE TELEPHONE NUMBER - Area Code.",
                type: 'Text'
              },
              phone_first_three_numbers: {
                key: 'F[0].Page_1[0].Nursing_Home_Officials_Phone_Middle_Three_Numbers[0]',
                question_text: '19. NURSING HOME OFFICIAL\'S OFFICE TELEPHONE NUMBER Enter middle three numbers.',
                type: 'Text'
              },
              phone_last_four_numbers: {
                key: 'F[0].Page_1[0].Nursing_Home_Official_Phone_Last_Four_Numbers[0]',
                question_text: '19. NURSING HOME OFFICIAL\'S OFFICE TELEPHONE NUMBER Enter last four numbers.',
                type: 'Text'
              }
            },
            # NOTE: 'signature' field is not mapped here - it's stamped onto the PDF via stamp_signature method
            signatureDate: {
              month: {
                key: 'F[0].Page_1[0].Date_Signed_Month[0]',
                question_text: '21. Date Signed. Enter 2 digit Month.  ',
                type: 'Text'
              },
              day: {
                key: 'F[0].Page_1[0].Date_Signed_Day[0]',
                question_text: '21. Date Signed. Enter 2 digit day.',
                type: 'Text'
              },
              year: {
                key: 'F[0].Page_1[0].Date_Signed_Year[0]',
                question_text: '21. Date Signed. Enter 4 digit year.',
                type: 'Text'
              }
            }
          }
        }.with_indifferent_access.freeze
      end
    end
  end
end
