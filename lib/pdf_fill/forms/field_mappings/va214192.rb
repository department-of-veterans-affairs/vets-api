# frozen_string_literal: true

module PdfFill
  module Forms
    module FieldMappings
      class Va214192
        KEY = {
          'veteranInformation' => {
            'fullName' => {
              'first' => {
                key: 'F[0].Page_1[0].Veterans_First_Name[0]',
                limit: 12,
                question_num: 3,
                question_text: 'VETERAN/BENEFICIARY\'S FIRST NAME'
              },
              'middle' => {
                key: 'F[0].Page_1[0].Middle_Initial1[0]',
                limit: 1,
                question_num: 3,
                question_text: 'VETERAN/BENEFICIARY\'S MIDDLE INITIAL'
              },
              'last' => {
                key: 'F[0].Page_1[0].Last_Name[0]',
                question_num: 3,
                question_text: 'VETERAN/BENEFICIARY\'S LAST NAME',
                limit: 18
              }
            },
            'ssn' => {
              'first' => {
                key: 'F[0].Page_1[0].SocialSecurityNumber_FirstThreeNumbers[0]',
                limit: 3
              },
              'second' => {
                key: 'F[0].Page_1[0].SocialSecurityNumber_SecondTwoNumbers[0]',
                limit: 2
              },
              'third' => {
                key: 'F[0].Page_1[0].SocialSecurityNumber_LastFourNumbers[0]',
                limit: 4
              }
            },
            'ssnPage2' => {
              'first' => {
                key: 'F[0].#subform[1].SocialSecurityNumber_FirstThreeNumbers[0]',
                limit: 3
              },
              'second' => {
                key: 'F[0].#subform[1].SocialSecurityNumber_SecondTwoNumbers[0]',
                limit: 2
              },
              'third' => {
                key: 'F[0].#subform[1].SocialSecurityNumber_LastFourNumbers[0]',
                limit: 4
              }
            },
            'vaFileNumber' => {
              key: 'F[0].Page_1[0].VA_File_Number_If_Applicable[0]',
              limit: 9
            },
            'dateOfBirth' => {
              'month' => {
                key: 'F[0].Page_1[0].DOBmonth[0]',
                limit: 2
              },
              'day' => {
                key: 'F[0].Page_1[0].DOBday[0]',
                limit: 2
              },
              'year' => {
                key: 'F[0].Page_1[0].DOByear[0]',
                limit: 4
              }
            }
          },
          'employmentInformation' => {
            'employerNameAndAddress' => {
              key: 'F[0].Page_1[0].nameandaddress[0]'
            },
            'returnAddress' => {
              key: 'F[0].Page_1[0].completeaddress[0]'
            },
            'typeOfWorkPerformed' => {
              key: 'F[0].Page_1[0].TypeOfWork[0]',
              question_num: 9,
              question_text: 'TYPE OF WORK PERFORMED',
              limit: 50

            },
            'beginningDateOfEmployment' => {
              'month' => {
                key: 'F[0].Page_1[0].DOBmonth[1]',
                limit: 2
              },
              'day' => {
                key: 'F[0].Page_1[0].DOBday[1]',
                limit: 2
              },
              'year' => {
                key: 'F[0].Page_1[0].DOByear[1]',
                limit: 4
              }
            },
            'endingDateOfEmployment' => {
              'month' => {
                key: 'F[0].Page_1[0].DOBmonth[2]',
                limit: 2
              },
              'day' => {
                key: 'F[0].Page_1[0].DOBday[2]',
                limit: 2
              },
              'year' => {
                key: 'F[0].Page_1[0].DOByear[2]',
                limit: 4
              }
            },
            'amountEarnedLast12MonthsOfEmployment' => {
              'thousands' => {
                key: 'F[0].Page_1[0].ThousandsDollarAmount[0]',
                limit: 3
              },
              'hundreds' => {
                key: 'F[0].Page_1[0].HundredsDollarAmount[0]',
                limit: 3
              },
              'cents' => {
                key: 'F[0].Page_1[0].CentsAmount[0]',
                limit: 2
              }
            },
            'timeLostLast12MonthsOfEmployment' => {
              key: 'F[0].Page_1[0].timelost[0]'
            },
            'hoursWorkedDaily' => {
              key: 'F[0].Page_1[0].NumberHoursWorkedDaily[0]',
              limit: 3
            },
            'hoursWorkedWeekly' => {
              key: 'F[0].Page_1[0].NumberHoursWorkedWeekly[0]',
              limit: 3
            },
            'concessions' => {
              key: 'F[0].Page_1[0].Concessions[0]',
              question_num: 13,
              question_text: 'CONCESSIONS',
              limit: 250
            },
            'terminationReason' => {
              key: 'F[0].Page_1[0].ReasonVeteranNotWorking[0]',
              limit: 120,
              question_num: 14,
              question_text: 'REASON FOR TERMINATION OF EMPLOYMENT'
            },
            'dateLastWorked' => {
              'month' => {
                key: 'F[0].Page_1[0].DOBmonth[4]',
                limit: 2
              },
              'day' => {
                key: 'F[0].Page_1[0].DOBday[4]',
                limit: 2
              },
              'year' => {
                key: 'F[0].Page_1[0].DOByear[4]',
                limit: 4
              }
            },
            'lastPaymentDate' => {
              'month' => {
                key: 'F[0].Page_1[0].DOBmonth[3]',
                limit: 2
              },
              'day' => {
                key: 'F[0].Page_1[0].DOBday[3]',
                limit: 2
              },
              'year' => {
                key: 'F[0].Page_1[0].DOByear[3]',
                limit: 4
              }
            },
            'lastPaymentGrossAmount' => {
              key: 'F[0].Page_1[0].grossamount[0]',
              limit: 13,
              question_text: 'GROSS AMOUNT OF LAST PAYMENT',
              question_num: 15
            },
            'lumpSumPaymentMade' => {
              key: 'F[0].Page_1[0].RadioButtonList[0]'
            },
            'grossAmountPaid' => {
              key: 'F[0].Page_1[0].grossamount[1]',
              limit: 16,
              question_text: 'Lump Sum GROSS AMOUNT PAID',
              question_num: 16
            },
            'datePaid' => {
              'month' => {
                key: 'F[0].Page_1[0].DOBmonth[5]',
                limit: 2
              },
              'day' => {
                key: 'F[0].Page_1[0].DOBday[5]',
                limit: 2
              },
              'year' => {
                key: 'F[0].Page_1[0].DOByear[5]',
                limit: 4
              }
            }
          },
          'militaryDutyStatus' => {
            'currentDutyStatus' => {
              key: 'F[0].Page_1[0].VeteransCurrentDutyStatus[0]',
              question_num: 17,
              question_text: 'VETERAN\'S CURRENT DUTY STATUS',
              limit: 180
            },
            'veteranDisabilitiesPreventMilitaryDuties' => {
              key: 'F[0].Page_1[0].RadioButtonList[1]'
            }
          },
          'benefitEntitlementPayments' => {
            'sickRetirementOtherBenefits' => {
              key: 'F[0].#subform[1].RadioButtonList[0]'
            },
            'typeOfBenefit' => {
              key: 'F[0].#subform[1].TYPEOFBENEFIT[0]',
              limit: 250,
              question_num: 19,
              question_text: 'TYPE OF BENEFIT'
            },
            'grossMonthlyAmountOfBenefit' => {
              'thousands' => {
                key: 'F[0].#subform[1].ThousandsDollarAmount[0]',
                limit: 3
              },
              'hundreds' => {
                key: 'F[0].#subform[1].HundredsDollarAmount[0]',
                limit: 3
              },
              'cents' => {
                key: 'F[0].#subform[1].CentsAmount[0]',
                limit: 2
              }
            },
            'dateBenefitBegan' => {
              'month' => {
                key: 'F[0].#subform[1].DOBmonth[0]',
                limit: 2
              },
              'day' => {
                key: 'F[0].#subform[1].DOBday[0]',
                limit: 2
              },
              'year' => {
                key: 'F[0].#subform[1].DOByear[0]',
                limit: 4
              }
            },
            'dateFirstPaymentIssued' => {
              'month' => {
                key: 'F[0].#subform[1].DOBmonth[1]',
                limit: 2
              },
              'day' => {
                key: 'F[0].#subform[1].DOBday[1]',
                limit: 2
              },
              'year' => {
                key: 'F[0].#subform[1].DOByear[1]',
                limit: 4
              }
            },
            'dateBenefitWillStop' => {
              'month' => {
                key: 'F[0].#subform[1].DOBmonth[2]',
                limit: 2
              },
              'day' => {
                key: 'F[0].#subform[1].DOBday[2]',
                limit: 2
              },
              'year' => {
                key: 'F[0].#subform[1].DOByear[2]',
                limit: 4
              }
            },
            'remarks' => {
              key: 'F[0].#subform[1].TYPEOFBENEFIT[1]',
              question_text: 'REMARKS',
              question_num: 22,
              limit: 1200
            }
          },
          'certification' => {
            'certificationDate' => {
              key: 'F[0].#subform[1].DateSigned[0]'
            },
            'signature' => {
              key: 'F[0].#subform[1].Digital_Signature[0]'
            }
          }
        }.freeze
      end
    end
  end
end
