# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va21674v2 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'veteran_information' => {
          'full_name' => {
            'first' => {
              key: 'form1[0].#subform[0].FirstNameofVeteran[0]',
              limit: 12,
              question_num: 1,
              question_suffix: 'A',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S NAME'
            },
            'middleInitial' => {
              key: 'form1[0].#subform[0].MiddleInitialofVeteran[0]',
              limit: 1,
              question_num: 1,
              question_suffix: 'B',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S NAME'
            },
            'last' => {
              key: 'form1[0].#subform[0].LastNameofVeteran[0]',
              limit: 18,
              question_num: 1,
              question_suffix: 'C',
              question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > VETERAN\'S NAME'
            }
          },
          'va_file_number' => {
            key: 'form1[0].#subform[0].VAFileNumber[0]',
            limit: 9,
            question_num: 2,
            question_text: 'VA FILE NUMBER'
          }
        }, # end veteran_information
        'dependents_application' => { # Update to remove this key
          'veteran_contact_information' => {
            'phone_number' => {
              'phone_area_code' => {
                key: 'form1[0].#subform[0].TelephoneNumber_AreaCode[0]',
                limit: 3,
                question_num: 16,
                question_suffix: 'D',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > TELEPHONE NUMBER'
              },
              'phone_first_three_numbers' => {
                key: 'form1[0].#subform[0].TelephoneNumber_FirstThreeNumbers[0]',
                limit: 3,
                question_num: 16,
                question_suffix: 'D',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > TELEPHONE NUMBER'
              },
              'phone_last_four_numbers' => {
                key: 'form1[0].#subform[0].TelephoneNumber_LastFourNumbers[0]',
                limit: 4,
                question_num: 16,
                question_suffix: 'D',
                question_text: 'VETERAN/CLAIMANT\'S IDENTIFICATION INFORMATION > TELEPHONE NUMBER'
              }
            },
            'international_phone_number' => {
              key: 'form1[0].#subform[0].TelephoneNumber_International[0]',
              limit: 12,
              question_num: 16,
              question_suffix: 'D',
              question_text: 'Enter international phone number (if applicable)'
            },
            'email_address' => {
              key: 'form1[0].#subform[0].email[0]',
              limit: 25,
              question_num: 3,
              question_text: 'E-MAIL ADDRESS OF VETERAN'
            },
            'email_address_two' => {
              key: 'form1[0].#subform[0].email[1]',
              limit: 25,
              question_num: 3,
              question_text: 'E-MAIL ADDRESS OF VETERAN'
            }
          }, # end veteran_contact_information
          'student_information' => {
            limit: 4,
            first_key: 'school_information',
            'remarks' => {
              key: 'form1[0].#subform[0].Remarks[0]',
              limit: 1000,
              question_num: 15,
              question_suffix: 'A',
              question_text: 'REMARKS'
            },
            'student_networth_information' => {
              'savings' => { # Update logic to seperate savings numbers
                'first' => {
                  key: 'form1[0].#subform[0].StudentSavings_FirstOne[0]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'A',
                  question_text: 'VALUE OF ESTATE > SAVINGS'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentSavings_SecondThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'A',
                  question_text: 'VALUE OF ESTATE > SAVINGS'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentSavings_ThirdThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'A',
                  question_text: 'VALUE OF ESTATE > SAVINGS'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentSavings_LastTwo[0]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'A',
                  question_text: 'VALUE OF ESTATE > SAVINGS'
                }
              },
              'securities' => {
                'first' => {
                  key: 'form1[0].#subform[0].StudentSecurities_FirstOne[0]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'B',
                  question_text: 'VALUE OF ESTATE > SECURITIES'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentSecurities_SecondThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'B',
                  question_text: 'VALUE OF ESTATE > SECURITIES'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentSecurities_ThirdThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'B',
                  question_text: 'VALUE OF ESTATE > SECURITIES'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentSecurities_LastTwo[0]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'B',
                  question_text: 'VALUE OF ESTATE > SECURITIES'
                }
              },
              'real_estate' => {
                'first' => {
                  key: 'form1[0].#subform[0].StudentRealEstate_FirstOne[0]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'C',
                  question_text: 'VALUE OF ESTATE > REAL ESTATE'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentRealEstate_SecondThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'C',
                  question_text: 'VALUE OF ESTATE > REAL ESTATE'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentRealEstate_ThirdThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'C',
                  question_text: 'VALUE OF ESTATE > REAL ESTATE'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentRealEstate_LastTwo[0]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'C',
                  question_text: 'VALUE OF ESTATE > REAL ESTATE'
                }
              },
              'other_assets' => {
                'first' => {
                  key: 'form1[0].#subform[0].StudentOtherAssets_FirstOne[0]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'D',
                  question_text: 'VALUE OF ESTATE > OTHER ASSETS'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentOtherAssets_SecondThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'D',
                  question_text: 'VALUE OF ESTATE > OTHER ASSETS'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentOtherAssets_ThirdThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'D',
                  question_text: 'VALUE OF ESTATE > OTHER ASSETS'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentOtherAssets_LastTwo[0]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'D',
                  question_text: 'VALUE OF ESTATE > OTHER ASSETS'
                }
              },
              'total_value' => {
                'first' => {
                  key: 'form1[0].#subform[0].StudentTotalValues_FirstOne[0]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'E',
                  question_text: 'VALUE OF ESTATE > TOTAL VALUE'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentTotalValues_SecondThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'E',
                  question_text: 'VALUE OF ESTATE > TOTAL VALUE'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentTotalValues_ThirdThree[0]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'E',
                  question_text: 'VALUE OF ESTATE > TOTAL VALUE'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentTotalValues_LastTwo[0]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'E',
                  question_text: 'VALUE OF ESTATE > TOTAL VALUE'
                }
              }
            },
            'student_expected_earnings_next_year' => {
              'earnings_from_all_employment' => { # Update - All student information to multiple fields
                'first' => {
                  key: 'form1[0].#subform[0].ExpectedEarningsFromAllEmployment_FirstTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > EARNINGS FROM ALL EMPLOYMENT'
                },
                'second' => {
                  key: 'form1[0].#subform[0].ExpectedEarningsFromAllEmployment_MiddleThree[0]',
                  limit: 3,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > EARNINGS FROM ALL EMPLOYMENT'
                },
                'third' => {
                  key: 'form1[0].#subform[0].ExpectedEarningsFromAllEmployment_LastTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > EARNINGS FROM ALL EMPLOYMENT'
                }
              },
              'annual_social_security_payments' => {
                'first' => {
                  key: 'form1[0].#subform[0].ExpectedAnnualSocialSecurity_FirstTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > ANNUAL SOCIAL SECURITY'
                },
                'second' => {
                  key: 'form1[0].#subform[0].ExpectedAnnualSocialSecurity_MiddleThree[0]',
                  limit: 3,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > ANNUAL SOCIAL SECURITY'
                },
                'third' => {
                  key: 'form1[0].#subform[0].ExpectedAnnualSocialSecurity_LastTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > ANNUAL SOCIAL SECURITY'
                }
              },
              'other_annuities_income' => {
                'first' => {
                  key: 'form1[0].#subform[0].ExpectedOtherAnnuities_FirstTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > OTHER ANNUITIES'
                },
                'second' => {
                  key: 'form1[0].#subform[0].ExpectedOtherAnnuities_MiddleThree[0]',
                  limit: 3,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > OTHER ANNUITIES'
                },
                'third' => {
                  key: 'form1[0].#subform[0].ExpectedOtherAnnuities_LastTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > OTHER ANNUITIES'
                }
              },
              'all_other_income' => {
                'first' => {
                  key: 'form1[0].#subform[0].ExpectedAllOtherIncome_FirstTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > ALL OTHER INCOME'
                },
                'second' => {
                  key: 'form1[0].#subform[0].ExpectedAllOtherIncome_MiddleThree[0]',
                  limit: 3,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > ALL OTHER INCOME'
                },
                'third' => {
                  key: 'form1[0].#subform[0].ExpectedAllOtherIncome_LastTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'C',
                  question_text: 'STUDENT\'S INFORMATION > EXPECTED > ALL OTHER INCOME'
                }
              }
            },
            'student_earnings_from_school_year' => {
              'earnings_from_all_employment' => {
                'first' => {
                  key: 'form1[0].#subform[0].ReceivedEarningsFromAllEmployment_FirstTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > EARNINGS FROM ALL EMPLOYMENT'
                },
                'second' => {
                  key: 'form1[0].#subform[0].ReceivedEarningsFromAllEmployment_MiddleThree[0]',
                  limit: 3,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > EARNINGS FROM ALL EMPLOYMENT'
                },
                'third' => {
                  key: 'form1[0].#subform[0].ReceivedEarningsFromAllEmployment_LastTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > EARNINGS FROM ALL EMPLOYMENT'
                }
              },
              'annual_social_security_payments' => {
                'first' => {
                  key: 'form1[0].#subform[0].ReceivedAnnualSocialSecurity_FirstTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > ANNUAL SOCIAL SECURITY'
                },
                'second' => {
                  key: 'form1[0].#subform[0].ReceivedAnnualSocialSecurity_MiddleThree[0]',
                  limit: 3,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > ANNUAL SOCIAL SECURITY'
                },
                'third' => {
                  key: 'form1[0].#subform[0].ReceivedAnnualSocialSecurity_LastTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > ANNUAL SOCIAL SECURITY'
                }
              },
              'other_annuities_income' => {
                'first' => {
                  key: 'form1[0].#subform[0].ReceivedOtherAnnuities_FirstTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > OTHER ANNUITIES'
                },
                'second' => {
                  key: 'form1[0].#subform[0].ReceivedOtherAnnuities_MiddleThree[0]',
                  limit: 3,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > OTHER ANNUITIES'
                },
                'third' => {
                  key: 'form1[0].#subform[0].ReceivedOtherAnnuities_LastTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > OTHER ANNUITIES'
                }
              },
              'all_other_income' => {
                'first' => {
                  key: 'form1[0].#subform[0].ReceivedAllOtherIncome_FirstTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > ALL OTHER INCOME'
                },
                'second' => {
                  key: 'form1[0].#subform[0].ReceivedAllOtherIncome_MiddleThree[0]',
                  limit: 3,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > ALL OTHER INCOME'
                },
                'third' => {
                  key: 'form1[0].#subform[0].ReceivedAllOtherIncome_LastTwo[0]',
                  limit: 2,
                  question_num: 13,
                  question_suffix: 'B',
                  question_text: 'STUDENT\'S INFORMATION > RECIEVED > ALL OTHER INCOME'
                }
              }
            },
            'school_information' => {
              'last_term_school_information' => {
                'term_begin' => {
                  'month' => {
                    key: 'form1[0].#subform[0].BeginDateofLastTerm.month[0]',
                    limit: 2,
                    question_num: 12,
                    question_suffix: 'B',
                    question_text: 'BEGINNING DATE OF LAST TERM (MM-DD-YYYY)'
                  },
                  'day' => {
                    key: 'form1[0].#subform[0].BeginDateofLastTerm.day[0]',
                    limit: 2,
                    question_num: 12,
                    question_suffix: 'B',
                    question_text: 'BEGINNING DATE OF LAST TERM (MM-DD-YYYY)'
                  },
                  'year' => {
                    key: 'form1[0].#subform[0].BeginDateofLastTerm.year[0]',
                    limit: 4,
                    question_num: 12,
                    question_suffix: 'B',
                    question_text: 'BEGINNING DATE OF LAST TERM (MM-DD-YYYY)'
                  }
                },
                'date_term_ended' => { # Update logic for helper
                  'month' => {
                    key: 'form1[0].#subform[0].EndDateofLastTerm.month[0]',
                    limit: 2,
                    question_num: 12,
                    question_suffix: 'C',
                    question_text: 'ENDING DATE OF LAST TERM (MM-DD-YYYY)'
                  },
                  'day' => {
                    key: 'form1[0].#subform[0].EndDateofLastTerm.day[0]',
                    limit: 2,
                    question_num: 12,
                    question_suffix: 'C',
                    question_text: 'ENDING DATE OF LAST TERM (MM-DD-YYYY)'
                  },
                  'year' => {
                    key: 'form1[0].#subform[0].EndDateofLastTerm.year[0]',
                    limit: 4,
                    question_num: 12,
                    question_suffix: 'C',
                    question_text: 'ENDING DATE OF LAST TERM (MM-DD-YYYY)'
                  }
                }
              },
              'current_term_dates' => {
                'official_school_start_date' => {
                  'month' => {
                    key: 'form1[0].#subform[0].OfficialStartDate.month[0]',
                    limit: 2,
                    question_num: 11,
                    question_suffix: 'A',
                    question_text: 'OFFICIAL BEGINNING DATE OF REGULAR TERM OR COURSE (MM/DD/YYYY)'
                  },
                  'day' => {
                    key: 'form1[0].#subform[0].OfficialStartDate.day[0]',
                    limit: 2,
                    question_num: 11,
                    question_suffix: 'A',
                    question_text: 'OFFICIAL BEGINNING DATE OF REGULAR TERM OR COURSE (MM/DD/YYYY)'
                  },
                  'year' => {
                    key: 'form1[0].#subform[0].OfficialStartDate.year[0]',
                    limit: 4,
                    question_num: 11,
                    question_suffix: 'A',
                    question_text: 'OFFICIAL BEGINNING DATE OF REGULAR TERM OR COURSE (MM/DD/YYYY)'
                  }
                },
                'expected_student_start_date' => {
                  'month' => {
                    key: 'form1[0].#subform[0].StudentStartDate.month[0]',
                    limit: 2,
                    question_num: 11,
                    question_suffix: 'B',
                    question_text: 'DATE STUDENT STARTED OR EXPECTS TO START COURSE (MM/DD/YYYY)'
                  },
                  'day' => {
                    key: 'form1[0].#subform[0].StudentStartDate.day[0]',
                    limit: 2,
                    question_num: 11,
                    question_suffix: 'B',
                    question_text: 'DATE STUDENT STARTED OR EXPECTS TO START COURSE (MM/DD/YYYY)'
                  },
                  'year' => {
                    key: 'form1[0].#subform[0].StudentStartDate.year[0]',
                    limit: 4,
                    question_num: 11,
                    question_suffix: 'B',
                    question_text: 'DATE STUDENT STARTED OR EXPECTS TO START COURSE (MM/DD/YYYY)'
                  }
                },
                'expected_graduation_date' => {
                  'month' => {
                    key: 'form1[0].#subform[0].ExpectedGraduation.month[0]',
                    limit: 2,
                    question_num: 11,
                    question_suffix: 'C',
                    question_text: 'EXPECTED DATE OF GRADUATION (MM/DD/YYYY)'
                  },
                  'day' => {
                    key: 'form1[0].#subform[0].ExpectedGraduation.day[0]',
                    limit: 2,
                    question_num: 11,
                    question_suffix: 'C',
                    question_text: 'EXPECTED DATE OF GRADUATION (MM/DD/YYYY)'
                  },
                  'year' => {
                    key: 'form1[0].#subform[0].ExpectedGraduation.year[0]',
                    limit: 4,
                    question_num: 11,
                    question_suffix: 'C',
                    question_text: 'EXPECTED DATE OF GRADUATION (MM/DD/YYYY)'
                  }
                }
              },
              'is_school_accredited' => { # Update logic to change parent key name
                'is_school_accredited_yes' => { key: 'form1[0].#subform[0].YES4[0]' },
                'is_school_accredited_no' => { key: 'form1[0].#subform[0].NO4[0]' }
              },
              'date_full_time_ended' => { # QUESTION - what does this map to? We already have date_term_ended and "dateChildLeftSchool": "2020-05-19"
                key: '',
                limit: '',
                question_num: '',
                question_suffix: '',
                question_text: ''
              },
              'student_is_enrolled_full_time' => {
                'full_time_yes' => { key: 'form1[0].#subform[0].YES2[0]' },
                'full_time_no' => { key: 'form1[0].#subform[0].NO2[0]' }
              },
              'name' => { 
                key: 'form1[0].#subform[0].FederalAssistanceProgram[0]',
                limit: 200,
                question_num: 9,
                question_suffix: 'A',
                question_text: 'Federally funded school or program'
              },
              'student_did_attend_school_last_term' => {
                'did_attend_yes' => { key: 'form1[0].#subform[0].YES3[0]' },
                'did_attend_no' => { key: 'form1[0].#subform[0].NO3[0]' }
              }
            },
            'type_of_program_or_benefit' => { # Update, need a check to make sure the right program is added to this field
              key: 'form1[0].#subform[0].TypeOfProgramOrBenefit[0]',
              limit: 50,
              question_num: 9,
              question_suffix: 'B',
              question_text: 'Type of Program or Benefit'
            },
            'tuition_is_paid_by_gov_agency' => { # Update logic for new key name
              'is_paid_yes' => { key: 'form1[0].#subform[0].YES1[0]' },
              'is_paid_no' => { key: 'form1[0].#subform[0].NO1[0]' }
            },
            'was_married' => { # Update logic for new key name
              'was_married_yes' => { key: 'form1[0].#subform[0].YES[0]' },
              'was_married_no' => { key: 'form1[0].#subform[0].NO[0]' }
            },
            'address' => { # Update logic to remap fields - street, postalCode address_line1 = street
              'street' => {
                key: 'form1[0].#subform[0].AddressofStudentStreet[0]',
                limit: 30,
                question_num: 8,
                question_text: 'Address of Student > No & Street'
              },
              'street2' => {
                key: 'form1[0].#subform[0].AddressofStudentAptNumber[0]',
                limit: 5,
                question_num: 8,
                question_text: 'Address of Student > Apt/Unit Number'
              },
              'city' => {
                key: 'form1[0].#subform[0].AddressofStudentCity[0]',
                limit: 18,
                question_num: 8,
                question_text: 'Address of Student > City'
              },
              'state' => {
                key: 'form1[0].#subform[0].AddressofStudentState[0]',
                limit: 2,
                question_num: 8,
                question_text: 'Address of Student > State'
              },
              'country' => {
                key: 'form1[0].#subform[0].AddressofStudentCountry[0]',
                limit: 2,
                question_num: 8,
                question_text: 'Address of Student > Country'
              },
              'postal_code' => {
                'firstFive' => {
                  key: 'form1[0].#subform[0].AddressofStudentPostCode_FirstFive0]',
                  limit: 5,
                  question_num: 8,
                  question_text: 'Address of Student > Zip Code (First Five Digits)'
                },
                'lastFour' => {
                  key: 'form1[0].#subform[0].AddressofStudentPostCode_LastFour[0]',
                  limit: 4,
                  question_num: 8,
                  question_text: 'Address of Student > Zip Code (Last Four Digits)'
                }
              }
            },
            'ssn' => { # Update logic to change parent key
              'first' => {
                key: 'form1[0].#subform[0].StudentSsn_FirstThree[0]',
                limit: 3,
                question_num: 5,
                question_suffix: 'A',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > SOCIAL SECURITY NUMBER'
              },
              'second' => {
                key: 'form1[0].#subform[0].StudentSsn_MiddleTwo[0]',
                limit: 2,
                question_num: 5,
                question_suffix: 'B',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > SOCIAL SECURITY NUMBER'
              },
              'third' => {
                key: 'form1[0].#subform[0].StudentSsn_LastFour[0]',
                limit: 4,
                question_num: 5,
                question_suffix: 'C',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > SOCIAL SECURITY NUMBER'
              }
            },
            'full_name' => {
              'first' => {
                key: 'form1[0].#subform[0].FirstNameofStudent[0]',
                limit: 12,
                question_num: 4,
                question_suffix: 'A',
                question_text: 'STUDENT\'S NAME'
              },
              'middleInitial' => {
                key: 'form1[0].#subform[0].MiddleInitialofStudent[0]',
                limit: 1,
                question_num: 4,
                question_suffix: 'B',
                question_text: 'STUDENT\'S NAME'
              },
              'last' => {
                key: 'form1[0].#subform[0].LastNameofStudent[0]',
                limit: 18,
                question_num: 4,
                question_suffix: 'C',
                question_text: 'STUDENT\'S NAME'
              }
            },
            'birth_date' => { # Update logic in helper
              'month' => {
                key: 'form1[0].#subform[0].Student_DOB.month[0]',
                limit: 2,
                question_num: 6,
                question_suffix: 'A',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > DATE OF BIRTH (MM-DD-YYYY)'
              },
              'day' => {
                key: 'form1[0].#subform[0].Student_DOB.day[0]',
                limit: 2,
                question_num: 6,
                question_suffix: 'B',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > DATE OF BIRTH (MM-DD-YYYY)'
              },
              'year' => {
                key: 'form1[0].#subform[0].Student_DOB.year[0]',
                limit: 4,
                question_num: 6,
                question_suffix: 'C',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > DATE OF BIRTH (MM-DD-YYYY)'
              }
            },
            'child_marriage' => { # Update helper to get childMarriage > dateMarried. Child marriage is top level of the payload
              limit: 4,
              first_key: 'month',
              'month' => {
                key: 'form1[0].#subform[0].Student_Date_of_Marriage.month[0]',
                limit: 2,
                question_num: 7,
                question_suffix: 'B',
                question_text: 'DATE OF MARRIAGE'
              },
              'day' => {
                key: 'form1[0].#subform[0].Student_Date_of_Marriage.day[0]',
                limit: 2,
                question_num: 7,
                question_suffix: 'B',
                question_text: 'DATE OF MARRIAGE'
              },
              'year' => {
                key: 'form1[0].#subform[0].Student_Date_of_Marriage.year[0]',
                limit: 4,
                question_num: 7,
                question_suffix: 'B',
                question_text: 'DATE OF MARRIAGE'
              }
            },
            'benefit_payment_date' => { # Update logic, previously date_payments_began
              'month' => {
                key: 'form1[0].#subform[0].DatePaymentsBegan.month[0]',
                limit: 2,
                question_num: 9,
                question_suffix: 'C',
                question_text: 'School Attendance Information > DATE PAYMENTS BEGAN (MM-DD-YYYY)'
              },
              'day' => {
                key: 'form1[0].#subform[0].DatePaymentsBegan.day[0]',
                limit: 2,
                question_num: 9,
                question_suffix: 'C',
                question_text: 'School Attendance Information > DATE PAYMENTS BEGAN (MM-DD-YYYY)'
              },
              'year' => {
                key: 'form1[0].#subform[0].DatePaymentsBegan.year[0]',
                limit: 4,
                question_num: 9,
                question_suffix: 'C',
                question_text: 'School Attendance Information > DATE PAYMENTS BEGAN (MM-DD-YYYY)'
              }
            }
          }, # end of student information
          'child_stopped_attending_school' => {
            limit: 4,
            first_key: 'date_child_left_school',
            'date_child_left_school' => {
              'month' => {
                key: 'form1[0].#subform[0].DateStoppedAttending.month[0]',
                limit: 2,
                question_num: 10,
                question_suffix: 'A',
                question_text: 'School Attendance Information > Date student stopped attending continuously (MM-DD-YYYY)' # rubocop:disable Layout/LineLength
              },
              'day' => {
                key: 'form1[0].#subform[0].DateStoppedAttending.day[0]',
                limit: 2,
                question_num: 10,
                question_suffix: 'A',
                question_text: 'School Attendance Information >Date student stopped attending continuously (MM-DD-YYYY)'
              },
              'year' => {
                key: 'form1[0].#subform[0].DateStoppedAttending.year[0]',
                limit: 4,
                question_num: 10,
                question_suffix: 'A',
                question_text: 'School Attendance Information > Date student stopped attending continuously (MM-DD-YYYY)' # rubocop:disable Layout/LineLength
              }
            }
          } # end of child_stopped_attending_school
        }, # end dependents_application
        'signature' => {
          key: 'form1[0].#subform[0].Signature_PrintName[0]',
          limit: 35,
          question_num: 16,
          question_suffix: 'A',
          question_text: 'SIGNATURE'
        },
        'signature_date' => {
          'month' => {
            key: 'form1[0].#subform[0].SignatureDate.month[0]',
            limit: 2,
            question_num: 16,
            question_suffix: 'B',
            question_text: 'DATE SIGNED (MM-DD-YYYY)'
          },
          'day' => {
            key: 'form1[0].#subform[0].SignatureDate.day[0]',
            limit: 2,
            question_num: 16,
            question_suffix: 'B',
            question_text: 'DATE SIGNED (MM-DD-YYYY)'
          },
          'year' => {
            key: 'form1[0].#subform[0].SignatureDate.year[0]',
            limit: 4,
            question_num: 16,
            question_suffix: 'B',
            question_text: 'DATE SIGNED (MM-DD-YYYY)'
          }
        }
      }.freeze

      def merge_fields(options = {})
        created_at = options[:created_at] if options[:created_at].present?
        expand_signature(@form_data['veteran_information']['full_name'], created_at&.to_date || Time.zone.today)
        @form_data['signature_date'] = split_date(@form_data['signatureDate'])
        veteran_contact_information = @form_data['dependents_application']['veteran_contact_information']
        veteran_contact_information['phone_number'] = expand_phone_number(veteran_contact_information['phone_number'])
        extract_middle_i(@form_data['veteran_information'], 'full_name')
        merge_dates
        merge_student_helpers

        @form_data
      end

      # rubocop:disable Metrics/MethodLength
      def merge_dates
        dependents_application = @form_data['dependents_application']
        # student_information = dependents_application['student_information']
        # puts @form_data.keys if @form_data
        # puts @form_data['dependents_application'].keys if @form_data['dependents_application']
        # puts @form_data['dependents_application']['student_information'].class if @form_data.dig('dependents_application', 'student_information')
        student_information = @form_data['dependents_application']['student_information'].first
        # puts "student_information class: #{student_information.class}"
        # school information is a child of student information
        
        school_information = student_information['school_information']

        current_term_dates = school_information['current_term_dates']
        child_stopped_attending_school = dependents_application['child_stopped_attending_school'].first
        last_term_school_information = school_information['last_term_school_information']
        child_marriage = dependents_application['child_marriage'].first

        student_information['birth_date'] =
          split_date(student_information['birth_date'])

        if current_term_dates.present?
          current_term_dates['official_school_start_date'] =
            split_date(current_term_dates['official_school_start_date'])
          current_term_dates['expected_student_start_date'] =
            split_date(current_term_dates['expected_student_start_date'])
          current_term_dates['expected_graduation_date'] = split_date(current_term_dates['expected_graduation_date'])
        end

        if child_stopped_attending_school.present?
          child_stopped_attending_school['birth_date'] = split_date(child_stopped_attending_school['birth_date'])
          child_stopped_attending_school['date_child_left_school'] =
            split_date(child_stopped_attending_school['date_child_left_school'])
        end

        if last_term_school_information.present?
          last_term_school_information['term_begin'] = split_date(last_term_school_information['term_begin'])
          last_term_school_information['date_term_ended'] = split_date(last_term_school_information['date_term_ended'])
        end

        if child_marriage.present?
          child_marriage['date_married'] =
            split_date(child_marriage['date_married'])
        end

        # handle old format of fields before merging in front end, remove once merged
        if student_information['benefit_payment_date'].present?
          benefit_payment_date = student_information['benefit_payment_date']
          student_information['benefit_payment_date'] = split_date(benefit_payment_date)
        end

        # if agency_or_program.present?
        #   agency_or_program['date_payments_began'] =
        #     split_date(agency_or_program['date_payments_began'])
        # end
      end
      # rubocop:enable Metrics/MethodLength

      def expand_phone_number(phone_number)
        phone_number = phone_number.delete('^0-9')
        {
          'phone_area_code' => phone_number[0..2],
          'phone_first_three_numbers' => phone_number[3..5],
          'phone_last_four_numbers' => phone_number[6..9]
        }
      end

      def merge_student_helpers
        dependents_application = @form_data['dependents_application']
        student_information = dependents_application['student_information'].first
        extract_middle_i(student_information, 'full_name')
        student_information['ssn'] =
          split_ssn(student_information['ssn'])

        student_information['address']['postal_code'] =
          split_postal_code(student_information['address'])
        student_information['address']['country'] =
          extract_country(student_information['address'])

        student_expected_earnings = student_information['student_expected_earnings_next_year']
        student_earnings = student_information['student_earnings_from_school_year']
        student_networth = student_information['student_networth_information']

        if student_expected_earnings.present?
          split_earnings(student_expected_earnings)
        end

        if student_earnings.present?
          split_earnings(student_earnings)
        end

        if student_networth.present?
          split_networth_information(student_networth)
        end

        format_checkboxes(dependents_application)
      end

      # override from form_helper
      def select_checkbox(value)
        value ? 'On' : 'Off'
      end

      def split_earnings(parent_object)
        return unless parent_object.present?
        keys_to_process = [
          'earnings_from_all_employment',
          'annual_social_security_payments',
          'other_annuities_income',
          'all_other_income'
        ]
      
        keys_to_process.each do |key|
          value = parent_object[key]
      
          next unless value.present?
      
          cleaned_value = value.to_s.gsub(/[^0-9]/, '').to_i
      
          parent_object[key] = {
            'first' => (cleaned_value / 1000).to_s,
            'second' => ((cleaned_value / 100) % 10).to_s,
            'third' => '00'
          }
        end
      
        parent_object
      end

      def split_networth_information(parent_object)
        return unless parent_object.present?
      
        keys_to_process = [
          'savings',
          'securities',
          'real_estate',
          'other_assets',
          'total_value'
        ]
      
        keys_to_process.each do |key|
          value = parent_object[key]
      
          next unless value.present?
      
          cleaned_value = value.to_s.gsub(/[^0-9]/, '').to_i
      
          first = (cleaned_value / 100000000).to_s                      # Million
          second = ((cleaned_value / 100000) % 1000).to_s.rjust(3, '0') # Thousands
          third = ((cleaned_value / 100) % 1000).to_s.rjust(3, '0')     # Hundreds
          last = "00"                                                   # Always zero cents
      
          parent_object[key] = {
            'first' => first,
            'second' => second,
            'third' => third,
            'last' => last
          }
        end
      
        parent_object
      end

      # rubocop:disable Metrics/MethodLength
      def format_checkboxes(dependents_application)
        student_information = dependents_application['student_information'].first
        was_married = student_information['was_married']
        student_information['was_married'] = {
          'was_married_yes' => select_checkbox(was_married),
          'was_married_no' => select_checkbox(!was_married)
        }

        is_paid = student_information['tuition_is_paid_by_gov_agency']
        student_information['tuition_is_paid_by_gov_agency'] = {
          'is_paid_yes' => select_checkbox(is_paid),
          'is_paid_no' => select_checkbox(!is_paid)
        }

        is_full_time = student_information['school_information']['student_is_enrolled_full_time']
        student_information['school_information']['student_is_enrolled_full_time'] = {
          'full_time_yes' => select_checkbox(is_full_time),
          'full_time_no' => select_checkbox(!is_full_time)
        }

        did_attend = student_information['school_information']['student_did_attend_school_last_term']
        student_information['school_information']['student_did_attend_school_last_term'] = {
          'did_attend_yes' => select_checkbox(did_attend),
          'did_attend_no' => select_checkbox(!did_attend)
        }

        is_school_accredited = student_information['school_information']['is_school_accredited']
        student_information['school_information']['is_school_accredited'] = {
          'is_school_accredited_yes' => select_radio_button(is_school_accredited),
          'is_school_accredited_no' => select_radio_button(!is_school_accredited)
        }
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
# rubocop:enable Metrics/ClassLength
