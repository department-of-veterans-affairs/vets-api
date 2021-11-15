# frozen_string_literal: true

module PdfFill
  module Forms
    class Va21674 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'veteran_information' => {
          'full_name' => {
            key: 'form1[0].#subform[0].NameofVeteran[0]',
            limit: 50,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'FIRST NAME-MIDDLE INITIAL-LAST NAME OF VETERAN'
          },
          'va_file_number' => {
            key: 'form1[0].#subform[0].VAFileNumber[0]',
            limit: 10,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'VA FILE NUMBER'
          }
        }, # end veteran_information
        'dependents_application' => {
          'veteran_contact_information' => {
            'phone_number' => {
              key: 'form1[0].#subform[0].TelePhoneNo.IncludeAreaCode[0]',
              limit: 16,
              question_num: 15,
              question_suffix: 'B',
              question_text: 'TELEPHONE NO.'
            },
            'email_address' => {
              key: 'form1[0].#subform[0].email[0]',
              limit: 25,
              question_num: 2,
              question_suffix: 'B',
              question_text: 'E-MAIL ADDRESS OF VETERAN'
            }
          }, # end veteran_contact_information
          'student_name_and_ssn' => {
            'full_name' => {
              key: 'form1[0].#subform[0].NameofStudent[0]',
              limit: 100,
              question_num: 4,
              question_suffix: 'A',
              question_text: 'FIRST NAME-MIDDLE INITIAL-LAST NAME OF STUDENT'
            },
            'ssn' => {
              key: 'form1[0].#subform[0].SSN[0]',
              limit: 9,
              question_num: 4,
              question_suffix: 'B',
              question_text: 'STUDENT\'S SOCIAL SECURITY NUMBER'
            },
            'birth_date' => {
              key: 'form1[0].#subform[0].Date[0]',
              limit: 10,
              question_num: 5,
              question_suffix: 'A',
              question_text: 'STUDENT\'S DATE OF BIRTH'
            }
          }, # end student_name_and_ssn
          'student_address_marriage_tuition' => {
            'was_married' => {
              'was_married_yes' => { key: 'form1[0].#subform[0].YES[0]' },
              'was_married_no' => { key: 'form1[0].#subform[0].NO[0]' }
            },
            'marriage_date' => {
              key: 'form1[0].#subform[0].DateofMarriage[0]',
              limit: 10,
              question_num: 5,
              question_suffix: 'C',
              question_text: 'DATE OF MARRIAGE'
            },
            'address' => {
              key: 'form1[0].#subform[0].AddressofStudent[0]',
              limit: 70,
              question_num: 6,
              question_suffix: 'A',
              question_text: 'ADDRESS OF STUDENT'
            },
            'tuition_is_paid_by_gov_agency' => {
              'is_paid_yes' => { key: 'form1[0].#subform[0].YES1[0]' },
              'is_paid_no' => { key: 'form1[0].#subform[0].NO1[0]' }
            },
            'agency_name' => {
              key: 'form1[0].#subform[0].AGENCYNAMEl[0]',
              limit: 200,
              question_num: 7,
              question_suffix: 'B',
              question_text: 'AGENCY NAME'
            },
            'date_payments_began' => {
              key: 'form1[0].#subform[0].datepaymentsbegan[0]',
              limit: 10,
              question_num: 7,
              question_suffix: 'C',
              question_text: 'DATE PAYMENTS BEGAN'
            }
          }, # end student_address_marriage_tuition
          'school_information' => {
            'address' => {
              key: 'form1[0].#subform[0].NAMEADDRESSSCHOOL[0]',
              limit: 100,
              question_num: 8,
              question_suffix: 'A',
              question_text: 'NAME AND ADDRESS OF SCHOOL FOR WHICH APPROVAL IS REQUESTED'
            },
            'training_program' => {
              key: 'form1[0].#subform[0].NAMETYPECOURSE[0]',
              limit: 40,
              question_num: 8,
              question_suffix: 'B',
              question_text: 'NAME OR TYPE OF COURSE OF EDUCATION OR TRAINING'
            }
          }, # end school_information
          'current_term_dates' => {
            'official_school_start_date' => {
              key: 'form1[0].#subform[0].OFFICIALBEGDATE[0]',
              limit: 10,
              question_num: 9,
              question_suffix: 'A',
              question_text: 'OFFICIAL BEGINNING DATE OF REGULAR TERM OR COURSE'
            },
            'expected_student_start_date' => {
              key: 'form1[0].#subform[0].DATESTUDENTSTARED[0]',
              limit: 10,
              question_num: 9,
              question_suffix: 'B',
              question_text: 'DATE STUDENT STARTED OR EXPECTS TO START COURSE'
            },
            'expected_graduation_date' => {
              key: 'form1[0].#subform[0].ExpectedDateofGrad[0]',
              limit: 10,
              question_num: 9,
              question_suffix: 'C',
              question_text: 'EXPECTED DATE OF GRADUATION'
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
              key: 'form1[0].#subform[0].BeginDateofLastTerm[0]',
              limit: 10,
              question_num: 11,
              question_suffix: 'E',
              question_text: 'BEGINNING DATE OF LAST TERM'
            },
            'date_term_ended' => {
              key: 'form1[0].#subform[0].EndingDateofLastTerm[0]',
              limit: 10,
              question_num: 11,
              question_suffix: 'F',
              question_text: 'ENDING DATE OF LAST TERM'
            }
          }
        }, # end dependents_application
        'signature' => {
          key: 'form1[0].#subform[0].Signature_PrintName[0]',
          limit: 35,
          question_num: 15,
          question_suffix: 'A',
          question_text: 'SIGNATURE'
        },
        'signatureDate' => {
          key: 'form1[0].#subform[0].Date17[0]'
        }
      }.freeze

      def merge_fields(_options = {})
        expand_signature(@form_data['veteran_information']['full_name'])

        merge_veteran_helpers
        merge_student_helpers
        merge_address_helpers

        @form_data
      end

      def merge_veteran_helpers
        veteran_info = @form_data['veteran_information']
        veteran_info['full_name'] = combine_full_name(veteran_info['full_name'])
      end

      def merge_student_helpers
        dependents_application = @form_data['dependents_application']
        student_info = dependents_application['student_name_and_ssn']
        student_info['full_name'] = combine_full_name(student_info['full_name'])

        format_checkboxes(dependents_application)
      end

      def merge_address_helpers
        addr_info = @form_data['dependents_application']
        format_address(addr_info['student_address_marriage_tuition'], include_name: false)

        format_address(addr_info['school_information']) if addr_info['school_information'].present?
        format_address(addr_info['last_term_school_information']) if addr_info['last_term_school_information'].present?
      end

      def format_address(address_info, include_name: true)
        address = combine_hash(
          address_info['address'],
          %w[
            address_line1
            address_line2
            address_line3
            city
            state_code
            zip_code
            country_name
          ],
          ', '
        )
        address.prepend("#{address_info['name']} ") if include_name
        address_info['address'] = address
      end

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
      end
    end
  end
end
