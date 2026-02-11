# frozen_string_literal: true

require 'dependents/error_classes'
require 'pdf_fill/forms/formatters/va21674v2'

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va21674v2 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR
      FORMATTER = PdfFill::Forms::Formatters::Va21674v2

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
        'dependents_application' => {
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
              key: 'form1[0].#subform[0].Remarks[%iterator%]',
              limit: 1000,
              question_num: 15,
              question_suffix: 'A',
              question_text: 'REMARKS'
            },
            'student_networth_information' => {
              'savings' => {
                'first' => {
                  key: 'form1[0].#subform[0].StudentSavings_FirstOne[%iterator%]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'A',
                  question_text: 'VALUE OF ESTATE > SAVINGS'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentSavings_SecondThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'A',
                  question_text: 'VALUE OF ESTATE > SAVINGS'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentSavings_ThirdThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'A',
                  question_text: 'VALUE OF ESTATE > SAVINGS'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentSavings_LastTwo[%iterator%]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'A',
                  question_text: 'VALUE OF ESTATE > SAVINGS'
                }
              },
              'securities' => {
                'first' => {
                  key: 'form1[0].#subform[0].StudentSecurities_FirstOne[%iterator%]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'B',
                  question_text: 'VALUE OF ESTATE > SECURITIES'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentSecurities_SecondThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'B',
                  question_text: 'VALUE OF ESTATE > SECURITIES'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentSecurities_ThirdThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'B',
                  question_text: 'VALUE OF ESTATE > SECURITIES'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentSecurities_LastTwo[%iterator%]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'B',
                  question_text: 'VALUE OF ESTATE > SECURITIES'
                }
              },
              'real_estate' => {
                'first' => {
                  key: 'form1[0].#subform[0].StudentRealEstate_FirstOne[%iterator%]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'C',
                  question_text: 'VALUE OF ESTATE > REAL ESTATE'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentRealEstate_SecondThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'C',
                  question_text: 'VALUE OF ESTATE > REAL ESTATE'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentRealEstate_ThirdThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'C',
                  question_text: 'VALUE OF ESTATE > REAL ESTATE'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentRealEstate_LastTwo[%iterator%]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'C',
                  question_text: 'VALUE OF ESTATE > REAL ESTATE'
                }
              },
              'other_assets' => {
                'first' => {
                  key: 'form1[0].#subform[0].StudentOtherAssets_FirstOne[%iterator%]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'D',
                  question_text: 'VALUE OF ESTATE > OTHER ASSETS'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentOtherAssets_SecondThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'D',
                  question_text: 'VALUE OF ESTATE > OTHER ASSETS'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentOtherAssets_ThirdThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'D',
                  question_text: 'VALUE OF ESTATE > OTHER ASSETS'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentOtherAssets_LastTwo[%iterator%]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'D',
                  question_text: 'VALUE OF ESTATE > OTHER ASSETS'
                }
              },
              'total_value' => {
                'first' => {
                  key: 'form1[0].#subform[0].StudentTotalValues_FirstOne[%iterator%]',
                  limit: 1,
                  question_num: 14,
                  question_suffix: 'E',
                  question_text: 'VALUE OF ESTATE > TOTAL VALUE'
                },
                'second' => {
                  key: 'form1[0].#subform[0].StudentTotalValues_SecondThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'E',
                  question_text: 'VALUE OF ESTATE > TOTAL VALUE'
                },
                'third' => {
                  key: 'form1[0].#subform[0].StudentTotalValues_ThirdThree[%iterator%]',
                  limit: 3,
                  question_num: 14,
                  question_suffix: 'E',
                  question_text: 'VALUE OF ESTATE > TOTAL VALUE'
                },
                'last' => {
                  key: 'form1[0].#subform[0].StudentTotalValues_LastTwo[%iterator%]',
                  limit: 2,
                  question_num: 14,
                  question_suffix: 'E',
                  question_text: 'VALUE OF ESTATE > TOTAL VALUE'
                }
              }
            },
            'student_expected_earnings_next_year' => {
              'earnings_from_all_employment' => {
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
                    key: 'form1[0].#subform[0].BeginDateofLastTerm.month[%iterator%]',
                    limit: 2,
                    question_num: 12,
                    question_suffix: 'B',
                    question_text: 'BEGINNING DATE OF LAST TERM (MM-DD-YYYY)'
                  },
                  'day' => {
                    key: 'form1[0].#subform[0].BeginDateofLastTerm.day[%iterator%]',
                    limit: 2,
                    question_num: 12,
                    question_suffix: 'B',
                    question_text: 'BEGINNING DATE OF LAST TERM (MM-DD-YYYY)'
                  },
                  'year' => {
                    key: 'form1[0].#subform[0].BeginDateofLastTerm.year[%iterator%]',
                    limit: 4,
                    question_num: 12,
                    question_suffix: 'B',
                    question_text: 'BEGINNING DATE OF LAST TERM (MM-DD-YYYY)'
                  }
                },
                'date_term_ended' => {
                  'month' => {
                    key: 'form1[0].#subform[0].EndDateofLastTerm.month[%iterator%]',
                    limit: 2,
                    question_num: 12,
                    question_suffix: 'C',
                    question_text: 'ENDING DATE OF LAST TERM (MM-DD-YYYY)'
                  },
                  'day' => {
                    key: 'form1[0].#subform[0].EndDateofLastTerm.day[%iterator%]',
                    limit: 2,
                    question_num: 12,
                    question_suffix: 'C',
                    question_text: 'ENDING DATE OF LAST TERM (MM-DD-YYYY)'
                  },
                  'year' => {
                    key: 'form1[0].#subform[0].EndDateofLastTerm.year[%iterator%]',
                    limit: 4,
                    question_num: 12,
                    question_suffix: 'C',
                    question_text: 'ENDING DATE OF LAST TERM (MM-DD-YYYY)'
                  }
                }
              },
              'date_full_time_ended' => {
                'month' => {
                  key: 'form1[0].#subform[0].DateStoppedAttending.month[%iterator%]',
                  limit: 2,
                  question_num: 10,
                  question_suffix: 'A',
                  question_text: 'School Attendance Information > Date student stopped attending continuously (MM-DD-YYYY)' # rubocop:disable Layout/LineLength
                },
                'day' => {
                  key: 'form1[0].#subform[0].DateStoppedAttending.day[%iterator%]',
                  limit: 2,
                  question_num: 10,
                  question_suffix: 'A',
                  question_text: 'School Attendance Information >Date student stopped attending continuously (MM-DD-YYYY)' # rubocop:disable Layout/LineLength
                },
                'year' => {
                  key: 'form1[0].#subform[0].DateStoppedAttending.year[%iterator%]',
                  limit: 4,
                  question_num: 10,
                  question_suffix: 'A',
                  question_text: 'School Attendance Information > Date student stopped attending continuously (MM-DD-YYYY)' # rubocop:disable Layout/LineLength
                }
              },
              'current_term_dates' => {
                'official_school_start_date' => {
                  'month' => {
                    key: 'form1[0].#subform[0].OfficialStartDate.month[%iterator%]',
                    limit: 2,
                    question_num: 11,
                    question_suffix: 'A',
                    question_text: 'OFFICIAL BEGINNING DATE OF REGULAR TERM OR COURSE (MM/DD/YYYY)'
                  },
                  'day' => {
                    key: 'form1[0].#subform[0].OfficialStartDate.day[%iterator%]',
                    limit: 2,
                    question_num: 11,
                    question_suffix: 'A',
                    question_text: 'OFFICIAL BEGINNING DATE OF REGULAR TERM OR COURSE (MM/DD/YYYY)'
                  },
                  'year' => {
                    key: 'form1[0].#subform[0].OfficialStartDate.year[%iterator%]',
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
              'is_school_accredited' => {
                'is_school_accredited_yes' => { key: 'form1[0].#subform[0].YES4[%iterator%]' },
                'is_school_accredited_no' => { key: 'form1[0].#subform[0].NO4[%iterator%]' }
              },
              'student_is_enrolled_full_time' => {
                'full_time_yes' => { key: 'form1[0].#subform[0].YES2[%iterator%]' },
                'full_time_no' => { key: 'form1[0].#subform[0].NO2[%iterator%]' }
              },
              'name' => {
                key: 'form1[0].#subform[0].FederalAssistanceProgram[%iterator%]',
                limit: 200,
                question_num: 9,
                question_suffix: 'A',
                question_text: 'Federally funded school or program'
              },
              'student_did_attend_school_last_term' => {
                'did_attend_yes' => { key: 'form1[0].#subform[0].YES3[%iterator%]' },
                'did_attend_no' => { key: 'form1[0].#subform[0].NO3[%iterator%]' }
              }
            },
            'type_of_program_or_benefit' => {
              key: 'form1[0].#subform[0].TypeOfProgramOrBenefit[%iterator%]',
              limit: 50,
              question_num: 9,
              question_suffix: 'B',
              question_text: 'Type of Program or Benefit'
            },
            'tuition_is_paid_by_gov_agency' => {
              'is_paid_yes' => { key: 'form1[0].#subform[0].YES1[%iterator%]' },
              'is_paid_no' => { key: 'form1[0].#subform[0].NO1[%iterator%]' }
            },
            'was_married' => {
              'was_married_yes' => { key: 'form1[0].#subform[0].YES[%iterator%]' },
              'was_married_no' => { key: 'form1[0].#subform[0].NO[%iterator%]' }
            },
            'address' => {
              'street' => {
                key: 'form1[0].#subform[0].AddressofStudentStreet[%iterator%]',
                limit: 30,
                question_num: 8,
                question_text: 'Address of Student > No & Street'
              },
              'street2' => {
                key: 'form1[0].#subform[0].AddressofStudentAptNumber[%iterator%]',
                limit: 5,
                question_num: 8,
                question_text: 'Address of Student > Apt/Unit Number'
              },
              'city' => {
                key: 'form1[0].#subform[0].AddressofStudentCity[%iterator%]',
                limit: 18,
                question_num: 8,
                question_text: 'Address of Student > City'
              },
              'state' => {
                key: 'form1[0].#subform[0].AddressofStudentState[%iterator%]',
                limit: 2,
                question_num: 8,
                question_text: 'Address of Student > State'
              },
              'country' => {
                key: 'form1[0].#subform[0].AddressofStudentCountry[%iterator%]',
                limit: 2,
                question_num: 8,
                question_text: 'Address of Student > Country'
              },
              'postal_code' => {
                'firstFive' => {
                  key: 'form1[0].#subform[0].AddressofStudentPostCode_FirstFive[%iterator%]',
                  limit: 5,
                  question_num: 8,
                  question_text: 'Address of Student > Zip Code (First Five Digits)'
                },
                'lastFour' => {
                  key: 'form1[0].#subform[0].AddressofStudentPostCode_LastFour[%iterator%]',
                  limit: 4,
                  question_num: 8,
                  question_text: 'Address of Student > Zip Code (Last Four Digits)'
                }
              }
            },
            'ssn' => {
              'first' => {
                key: 'form1[0].#subform[0].StudentSsn_FirstThree[%iterator%]',
                limit: 3,
                question_num: 5,
                question_suffix: 'A',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > SOCIAL SECURITY NUMBER'
              },
              'second' => {
                key: 'form1[0].#subform[0].StudentSsn_MiddleTwo[%iterator%]',
                limit: 2,
                question_num: 5,
                question_suffix: 'B',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > SOCIAL SECURITY NUMBER'
              },
              'third' => {
                key: 'form1[0].#subform[0].StudentSsn_LastFour[%iterator%]',
                limit: 4,
                question_num: 5,
                question_suffix: 'C',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > SOCIAL SECURITY NUMBER'
              }
            },
            'full_name' => {
              'first' => {
                key: 'form1[0].#subform[0].FirstNameofStudent[%iterator%]',
                limit: 12,
                question_num: 4,
                question_suffix: 'A',
                question_text: 'STUDENT\'S NAME'
              },
              'middleInitial' => {
                key: 'form1[0].#subform[0].MiddleInitialofStudent[%iterator%]',
                limit: 1,
                question_num: 4,
                question_suffix: 'B',
                question_text: 'STUDENT\'S NAME'
              },
              'last' => {
                key: 'form1[0].#subform[0].LastNameofStudent[%iterator%]',
                limit: 18,
                question_num: 4,
                question_suffix: 'C',
                question_text: 'STUDENT\'S NAME'
              }
            },
            'birth_date' => {
              'month' => {
                key: 'form1[0].#subform[0].Student_DOB.month[%iterator%]',
                limit: 2,
                question_num: 6,
                question_suffix: 'A',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > DATE OF BIRTH (MM-DD-YYYY)'
              },
              'day' => {
                key: 'form1[0].#subform[0].Student_DOB.day[%iterator%]',
                limit: 2,
                question_num: 6,
                question_suffix: 'B',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > DATE OF BIRTH (MM-DD-YYYY)'
              },
              'year' => {
                key: 'form1[0].#subform[0].Student_DOB.year[%iterator%]',
                limit: 4,
                question_num: 6,
                question_suffix: 'C',
                question_text: 'STUDENT\'S IDENTIFICATION INFORMATION > DATE OF BIRTH (MM-DD-YYYY)'
              }
            },
            'benefit_payment_date' => {
              'month' => {
                key: 'form1[0].#subform[0].DatePaymentsBegan.month[%iterator%]',
                limit: 2,
                question_num: 9,
                question_suffix: 'C',
                question_text: 'School Attendance Information > DATE PAYMENTS BEGAN (MM-DD-YYYY)'
              },
              'day' => {
                key: 'form1[0].#subform[0].DatePaymentsBegan.day[%iterator%]',
                limit: 2,
                question_num: 9,
                question_suffix: 'C',
                question_text: 'School Attendance Information > DATE PAYMENTS BEGAN (MM-DD-YYYY)'
              },
              'year' => {
                key: 'form1[0].#subform[0].DatePaymentsBegan.year[%iterator%]',
                limit: 4,
                question_num: 9,
                question_suffix: 'C',
                question_text: 'School Attendance Information > DATE PAYMENTS BEGAN (MM-DD-YYYY)'
              }
            }
          }, # end of student information
          'child_marriage' => {
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
          }
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
        },
        # start overflow
        'student_expected_earnings_next_year_overflow' => {
          'earnings_from_all_employment' => {
            key: 'form1[0].#subform[0].ExpectedEarnings',
            limit: 0,
            question_num: 13,
            question_suffix: 'C',
            question_text: 'EARNINGS FROM ALL EMPLOYMENT',
            overflow_only: true
          },
          'annual_social_security_payments' => {
            key: 'form1[0].#subform[0].ExpectedSocialSecurity',
            limit: 0,
            question_num: 13,
            question_suffix: 'C',
            question_text: 'ANNUAL SOCIAL SECURITY',
            overflow_only: true
          },
          'other_annuities_income' => {
            key: 'form1[0].#subform[0].ExpectedOtherAnnuities',
            limit: 0,
            question_num: 13,
            question_suffix: 'C',
            question_text: 'OTHER ANNUITIES',
            overflow_only: true
          },
          'all_other_income' => {
            key: 'form1[0].#subform[0].ExpectedAllOtherIncome',
            limit: 0,
            question_num: 13,
            question_suffix: 'C',
            question_text: 'ALL OTHER INCOME',
            overflow_only: true
          }
        },
        'student_earnings_from_school_year_overflow' => {
          'earnings_from_all_employment' => {
            key: 'form1[0].#subform[0].ReceivedEarnings',
            limit: 0,
            question_num: 13,
            question_suffix: 'B',
            question_text: 'EARNINGS FROM ALL EMPLOYMENT',
            overflow_only: true
          },
          'annual_social_security_payments' => {
            key: 'form1[0].#subform[0].ReceivedSocialSecurity',
            limit: 0,
            question_num: 13,
            question_suffix: 'B',
            question_text: 'ANNUAL SOCIAL SECURITY',
            overflow_only: true
          },
          'other_annuities_income' => {
            key: 'form1[0].#subform[0].ReceivedOtherAnnuities',
            limit: 0,
            question_num: 13,
            question_suffix: 'B',
            question_text: 'OTHER ANNUITIES',
            overflow_only: true
          },
          'all_other_income' => {
            key: 'form1[0].#subform[0].ReceivedAllOtherIncome',
            limit: 0,
            question_num: 13,
            question_suffix: 'B',
            question_text: 'ALL OTHER INCOME',
            overflow_only: true
          }
        },
        'student_networth_information_overflow' => {
          'savings' => {
            key: 'form1[0].#subform[0].StudentSavings',
            limit: 0,
            question_num: 14,
            question_suffix: 'A',
            question_text: 'SAVINGS',
            overflow_only: true
          },
          'securities' => {
            key: 'form1[0].#subform[0].StudentSecurities',
            limit: 0,
            question_num: 14,
            question_suffix: 'B',
            question_text: 'SECURITIES',
            overflow_only: true
          },
          'real_estate' => {
            key: 'form1[0].#subform[0].StudentRealEstate',
            limit: 0,
            question_num: 14,
            question_suffix: 'C',
            question_text: 'REAL ESTATE',
            overflow_only: true
          },
          'other_assets' => {
            key: 'form1[0].#subform[0].StudentOtherAssets',
            limit: 0,
            question_num: 14,
            question_suffix: 'D',
            question_text: 'OTHER ASSETS',
            overflow_only: true
          },
          'total_value' => {
            key: 'form1[0].#subform[0].StudentTotalValues',
            limit: 0,
            question_num: 14,
            question_suffix: 'E',
            question_text: 'TOTAL VALUE',
            overflow_only: true
          }
        } # end overflow
      }.freeze

      def merge_fields(options = {})
        created_at = options[:created_at] if options[:created_at].present?
        student = options[:student]
        @form_data['dependents_application']['student_information'] = [student.deep_dup]
        unless @form_data['veteran_information']
          @form_data['veteran_information'] = @form_data.dig('dependents_application', 'veteran_information')
        end

        # We add the user data to the form data in some jobs. It should always be present here.
        raise Dependents::ErrorClasses::MissingVeteranInfoError unless @form_data['veteran_information']

        expand_signature(@form_data['veteran_information']['full_name'], created_at&.to_date || Time.zone.today)
        @form_data['signature_date'] = split_date(@form_data['signatureDate'])
        veteran_contact_information = @form_data['dependents_application']['veteran_contact_information']
        veteran_contact_information['phone_number'] =
          FORMATTER.expand_phone_number(veteran_contact_information['phone_number'])
        extract_middle_i(@form_data['veteran_information'], 'full_name')
        merge_dates
        merge_student_helpers
        FORMATTER.handle_overflows(@form_data)

        @form_data
      end

      # rubocop:disable Metrics/MethodLength
      def merge_dates
        students_information = @form_data['dependents_application']['student_information']
        if students_information.present?
          students_information.each do |student_information|
            school_information = student_information['school_information']
            current_term_dates = school_information['current_term_dates']
            last_term_school_information = school_information['last_term_school_information']

            student_information['birth_date'] = split_date(student_information['birth_date'])
            marriage_date = student_information['marriage_date']
            @form_data['dependents_application']['child_marriage'] = split_date(marriage_date)

            if last_term_school_information.present?
              last_term_school_information['term_begin'] = split_date(last_term_school_information['term_begin'])
              last_term_school_information['date_term_ended'] =
                split_date(last_term_school_information['date_term_ended'])
            end

            if current_term_dates.present?
              current_term_dates['official_school_start_date'] =
                split_date(current_term_dates['official_school_start_date'])
              current_term_dates['expected_student_start_date'] =
                split_date(current_term_dates['expected_student_start_date'])
              current_term_dates['expected_graduation_date'] =
                split_date(current_term_dates['expected_graduation_date'])
            end

            if student_information['benefit_payment_date'].present?
              benefit_payment_date = student_information['benefit_payment_date']
              student_information['benefit_payment_date'] = split_date(benefit_payment_date)
            end

            if school_information['date_full_time_ended'].present?
              date_full_time_ended = school_information['date_full_time_ended']
              school_information['date_full_time_ended'] = split_date(date_full_time_ended)
            end
          end
        end
      end

      def merge_student_helpers
        dependents_application = @form_data['dependents_application']
        students_information = @form_data['dependents_application']['student_information']
        if students_information.present?
          students_information.each do |student_information|
            extract_middle_i(student_information, 'full_name')
            student_information['ssn'] = split_ssn(student_information['ssn'])
            student_information['address']['postal_code'] = split_postal_code(student_information['address'])
            student_information['address']['country'] = extract_country(student_information['address'])
            student_expected_earnings = student_information['student_expected_earnings_next_year']
            student_earnings = student_information['student_earnings_from_school_year']
            student_networth = student_information['student_networth_information']
            type_of_program_or_benefit = student_information['type_of_program_or_benefit']
            if type_of_program_or_benefit.present?
              program_information = FORMATTER.get_program(type_of_program_or_benefit)
            end
            student_information['type_of_program_or_benefit'] = program_information if program_information.present?
            FORMATTER.split_earnings(student_expected_earnings) if student_expected_earnings.present?
            FORMATTER.split_earnings(student_earnings) if student_earnings.present?
            FORMATTER.split_networth_information(student_networth) if student_networth.present?
          end
        end
        FORMATTER.format_checkboxes(dependents_application)
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
# rubocop:enable Metrics/ClassLength
