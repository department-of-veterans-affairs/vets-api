# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va21674 < FormBase
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
          'student_name_and_ssn' => {
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
            'ssn' => {
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
            'birth_date' => {
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
            }
          }, # end student_name_and_ssn
          'student_address_marriage_tuition' => {
            'was_married' => {
              'was_married_yes' => { key: 'form1[0].#subform[0].YES[0]' },
              'was_married_no' => { key: 'form1[0].#subform[0].NO[0]' }
            },
            'marriage_date' => {
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
            'address' => {
              'address_line1' => {
                key: 'form1[0].#subform[0].AddressofStudentStreet[0]',
                limit: 30,
                question_num: 8,
                question_suffix: 'A',
                question_text: 'Address of Student > No & Street'
              },
              'address_line2' => {
                key: 'form1[0].#subform[0].AddressofStudentAptNumber[0]',
                limit: 5,
                question_num: 8,
                question_suffix: 'B',
                question_text: 'Address of Student > Apt/Unit Number'
              },
              'city' => {
                key: 'form1[0].#subform[0].AddressofStudentCity[0]',
                limit: 18,
                question_num: 8,
                question_suffix: 'C',
                question_text: 'Address of Student > City'
              },
              'state_code' => {
                key: 'form1[0].#subform[0].AddressofStudentState[0]',
                limit: 2,
                question_num: 8,
                question_suffix: 'D',
                question_text: 'Address of Student > State'
              },
              'country_name' => {
                key: 'form1[0].#subform[0].AddressofStudentCountry[0]',
                limit: 2,
                question_num: 8,
                question_suffix: 'E',
                question_text: 'Address of Student > Country'
              },
              'zip_code' => {
                'firstFive' => {
                  key: 'form1[0].#subform[0].AddressofStudentPostCode_FirstFive0]',
                  limit: 5,
                  question_num: 8,
                  question_suffix: 'F',
                  question_text: 'Address of Student > Zip Code (First Five Digits)'
                },
                'lastFour' => {
                  key: 'form1[0].#subform[0].AddressofStudentPostCode_LastFour0]',
                  limit: 4,
                  question_num: 8,
                  question_suffix: 'G',
                  question_text: 'Address of Student > Zip Code (Last Four Digits)'
                }
              }
            },
            'tuition_is_paid_by_gov_agency' => {
              'is_paid_yes' => { key: 'form1[0].#subform[0].YES1[0]' },
              'is_paid_no' => { key: 'form1[0].#subform[0].NO1[0]' }
            },
            'agency_name' => { # temporary addition while new fields have not been added that changes the schema
              key: 'form1[0].#subform[0].FederalAssistanceProgram[0]',
              limit: 200,
              question_num: 9,
              question_suffix: 'A',
              question_text: 'Federally funded school or program'
            },
            'date_payments_began' => { # temporary addition while new fields have not been added that changes the schema
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
          }, # end student_address_marriage_tuition
          'agency_or_program' => {
            'agency_name' => {
              key: 'form1[0].#subform[0].FederalAssistanceProgram[0]',
              limit: 200,
              question_num: 9,
              question_suffix: 'A',
              question_text: 'Federally funded school or program'
            },
            'type_of_program_or_benefit' => {
              key: 'form1[0].#subform[0].TypeOfProgramOrBenefit[0]',
              limit: 50,
              question_num: 9,
              question_suffix: 'B',
              question_text: 'Type of Program or Benefit'
            },
            'date_payments_began' => {
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
          }, # end agency_or_program
          'school_information' => {
            'training_program' => {
              key: 'form1[0].#subform[0].FederalAssistanceType[0]',
              limit: 200,
              question_num: 9,
              question_suffix: 'B',
              question_text: 'Type of program or benefit'
            }
          }, # end school_information
          'current_term_dates' => {
            'is_school_accredited' => {
              'is_school_accredited_yes' => { key: 'form1[0].#subform[0].YES4[0]' },
              'is_school_accredited_no' => { key: 'form1[0].#subform[0].NO4[0]' }
            },
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
          }, # end current_term_dates
          'program_information' => {
            'student_is_enrolled_full_time' => {
              'full_time_yes' => { key: 'form1[0].#subform[0].YES2[0]' },
              'full_time_no' => { key: 'form1[0].#subform[0].NO2[0]' }
            },
            'course_of_study' => {
              key: 'form1[0].#subform[0].Subject[0]',
              limit: 40,
              question_num: 10,
              question_suffix: 'B',
              question_text: 'SUBJECT FOR WHICH STUDENT IS ENROLLED'
            },
            'classes_per_week' => {
              key: 'form1[0].#subform[0].NumberofSession[0]',
              limit: 25,
              question_num: 10,
              question_suffix: 'C',
              question_text: 'NUMBER OF SESSIONS PER WEEK'
            },
            'hours_per_week' => {
              key: 'form1[0].#subform[0].HoursPerWeek[0]',
              limit: 25,
              question_num: 10,
              question_suffix: 'D',
              question_text: 'HOURS PER WEEK'
            }
          }, # end program_information
          'child_stopped_attending_school' => {
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
          },
          'student_did_attend_school_last_term' => {
            'did_attend_yes' => { key: 'form1[0].#subform[0].YES3[0]' },
            'did_attend_no' => { key: 'form1[0].#subform[0].NO3[0]' }
          },
          'last_term_school_information' => {
            'address' => {
              key: 'form1[0].#subform[0].NameSchoolAttend[0]',
              limit: 100,
              question_num: 11,
              question_suffix: 'B',
              question_text: 'NAME AND ADDRESS OF SCHOOL ATTENDED LAST TERM'
            },
            'classes_per_week' => {
              key: 'form1[0].#subform[0].NumberofSessionPerWeek[0]',
              limit: 10,
              question_num: 11,
              question_suffix: 'C',
              question_text: 'NO. OF SESSIONS PER WEEK'
            },
            'hours_per_week' => {
              key: 'form1[0].#subform[0].HoursPerWeek2[0]',
              limit: 10,
              question_num: 11,
              question_suffix: 'D',
              question_text: 'HOURS PER WEEK'
            },
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
            'date_term_ended' => {
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
        }
      }.freeze

      def merge_fields(options = {})
        created_at = options[:created_at] if options[:created_at].present?

        unless @form_data['veteran_information']
          @form_data['veteran_information'] = @form_data.dig('dependents_application', 'veteran_information')
        end

        expand_signature(@form_data['veteran_information']['full_name'], created_at&.to_date || Time.zone.today)

        @form_data['signature_date'] = split_date(@form_data['signatureDate'])

        veteran_contact_information = @form_data['dependents_application']['veteran_contact_information']

        veteran_contact_information['phone_number'] = expand_phone_number(veteran_contact_information['phone_number'])
        merge_dates
        merge_student_helpers

        @form_data
      end

      # rubocop:disable Metrics/MethodLength
      def merge_dates
        dependents_application = @form_data['dependents_application']
        current_term_dates = dependents_application['current_term_dates']
        child_stopped_attending_school = dependents_application['child_stopped_attending_school']
        last_term_school_information = dependents_application['last_term_school_information']
        student_address_marriage_tuition = dependents_application['student_address_marriage_tuition']
        agency_or_program = dependents_application['agency_or_program']

        dependents_application['student_name_and_ssn']['birth_date'] =
          split_date(dependents_application['student_name_and_ssn']['birth_date'])

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

        if student_address_marriage_tuition.present?
          student_address_marriage_tuition['marriage_date'] =
            split_date(student_address_marriage_tuition['marriage_date'])

          # handle old format of fields before merging in front end, remove once merged
          if student_address_marriage_tuition['date_payments_began'].present?
            date_payments_began = student_address_marriage_tuition['date_payments_began']
            student_address_marriage_tuition['date_payments_began'] = split_date(date_payments_began)
          end
        end

        if agency_or_program.present?
          agency_or_program['date_payments_began'] =
            split_date(agency_or_program['date_payments_began'])
        end
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
        dependents_application['student_name_and_ssn']['ssn'] =
          split_ssn(dependents_application['student_name_and_ssn']['ssn'])

        dependents_application['student_address_marriage_tuition']['address']['zip_code'] =
          split_postal_code(dependents_application['student_address_marriage_tuition']['address'])
        dependents_application['student_address_marriage_tuition']['address']['country_name'] =
          extract_country(dependents_application['student_address_marriage_tuition']['address'])

        format_checkboxes(dependents_application)
      end

      # override from form_helper
      def select_checkbox(value)
        value ? 'On' : 'Off'
      end

      # rubocop:disable Metrics/MethodLength
      def format_checkboxes(dependents_application)
        was_married = dependents_application['student_address_marriage_tuition']['was_married']
        dependents_application['student_address_marriage_tuition']['was_married'] = {
          'was_married_yes' => select_checkbox(was_married),
          'was_married_no' => select_checkbox(!was_married)
        }

        is_paid = dependents_application['student_address_marriage_tuition']['tuition_is_paid_by_gov_agency']
        dependents_application['student_address_marriage_tuition']['tuition_is_paid_by_gov_agency'] = {
          'is_paid_yes' => select_checkbox(is_paid),
          'is_paid_no' => select_checkbox(!is_paid)
        }

        is_full_time = dependents_application['program_information']['student_is_enrolled_full_time']
        dependents_application['program_information']['student_is_enrolled_full_time'] = {
          'full_time_yes' => select_checkbox(is_full_time),
          'full_time_no' => select_checkbox(!is_full_time)
        }

        did_attend = dependents_application['student_did_attend_school_last_term']
        dependents_application['student_did_attend_school_last_term'] = {
          'did_attend_yes' => select_checkbox(did_attend),
          'did_attend_no' => select_checkbox(!did_attend)
        }

        current_term_dates = dependents_application['current_term_dates']
        if current_term_dates.present?
          is_school_accredited = current_term_dates['is_school_accredited']
          dependents_application['current_term_dates']['is_school_accredited'] = {
            'is_school_accredited_yes' => select_radio_button(is_school_accredited),
            'is_school_accredited_no' => select_radio_button(!is_school_accredited)
          }
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
# rubocop:enable Metrics/ClassLength
