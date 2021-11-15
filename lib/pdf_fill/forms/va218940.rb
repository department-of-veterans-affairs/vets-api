# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'

# rubocop:disable Metrics/ClassLength
module PdfFill
  module Forms
    class Va218940 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[0].VeteransFirstName[0]',
            limit: 12,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[0].VeteransMiddleInitial[0]'
          },
          'last' => {
            key: 'form1[0].#subform[0].VeteransLastName[0]',
            limit: 18,
            question_num: 1,
            question_text: "VETERAN/BENEFICIARY'S LAST NAME"
          }
        },
        'veteranAddress' => {
          question_num: 5,
          question_text: 'MAILING ADDRESS',
          'street' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 5,
            question_suffix: 'A',
            question_text: 'Number and Street'
          },
          'street2' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 5,
            question_suffix: 'B',
            question_text: 'Apartment or Unit Number'
          },
          'city' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_City[0]',
            limit: 18,
            question_num: 5,
            question_suffix: 'C',
            question_text: 'City'
          },
          'state' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_StateOrProvince[0]'
          },
          'country' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_Country[0]',
            limit: 2
          },
          'postalCode' => {
            'firstFive' => {
              key: 'form1[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            },
            'lastFour' => {
              key: 'form1[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
            }
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[0].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[0].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[0].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber1' => {
          'first' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[1].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_FirstThreeNumbers[2]'
          },
          'second' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_SecondTwoNumbers[2]'
          },
          'third' => {
            key: 'form1[0].#subform[2].VeteransSocialSecurityNumber_LastFourNumbers[2]'
          }
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[0].VAFileNumber[0]'
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[0].DOBmonth[0]'
          },
          'day' => {
            key: 'form1[0].#subform[0].DOBday[0]'
          },
          'year' => {
            key: 'form1[0].#subform[0].DOByear[0]'
          }
        },
        'email' => {
          key: 'form1[0].#subform[0].EmailAddress[0]'
        },
        'veteranPhone' => {
          key: 'form1[0].#subform[0].TelephoneNumber_IncludeAreaCode[0]'
        },
        'signature' => {
          key: 'form1[0].#subform[2].Signature[2]'
        },
        'signatureDate' => {
          key: 'form1[0].#subform[2].DateSigned[0]',
          format: 'date'
        },
        'serviceConnectedDisability' => {
          key: 'form1[0].#subform[0].ServiceConnectedDisability[0]',
          limit: 90,
          question_num: 8,
          question_text: 'SERVICE CONNECTED DISABILITY'
        },
        'wasHospitalizedYes' => {
          key: 'form1[0].#subform[0].CheckBoxYes[0]'
        },
        'wasHospitalizedNo' => {
          key: 'form1[0].#subform[0].CheckBoxNo[0]'
        },
        'education' => {
          'checkbox' => {
            'gradeSchool1' => {
              key: 'gradeSchool1'
            },
            'gradeSchool2' => {
              key: 'gradeSchool2'
            },
            'gradeSchool3' => {
              key: 'gradeSchool3'
            },
            'gradeSchool4' => {
              key: 'gradeSchool4'
            },
            'gradeSchool5' => {
              key: 'gradeSchool5'
            },
            'gradeSchool6' => {
              key: 'gradeSchool6'
            },
            'gradeSchool7' => {
              key: 'gradeSchool7'
            },
            'gradeSchool8' => {
              key: 'gradeSchool8'
            },
            'highSchool1' => {
              key: 'highSchool1'
            },
            'highSchool2' => {
              key: 'highSchool2'
            },
            'highSchool3' => {
              key: 'highSchool3'
            },
            'highSchool4' => {
              key: 'highSchool4'
            },
            'college1' => {
              key: 'college1'
            },
            'college2' => {
              key: 'college2'
            },
            'college3' => {
              key: 'college3'
            },
            'college4' => {
              key: 'college4'
            }
          }
        },
        'trainingPreDisabledYes' => {
          key: 'receivedOtherTrainingPreDisabled1'
        },
        'trainingPreDisabledNo' => {
          key: 'receivedOtherTrainingPreDisabled0'
        },
        'trainingPostUnEmployYes' => {
          key: 'form1[0].#subform[1].CheckBoxYes[7]'
        },
        'trainingPostUnEmployNo' => {
          key: 'form1[0].#subform[1].CheckBoxNo[7]'
        },
        'otherEducationTrainingPreUnemployability' => {
          limit: 1,
          question_text: 'Other Education or Training Prior to Unemployability',
          question_num: 24,
          first_key: 'name',
          'name' => {
            key: 'form1[0].#subform[1].TypeOfEducationOrTraining[1]'
          },
          'dates' => {
            'from' => {
              key: 'form1[0].#subform[1].Date[7]',
              format: 'date'
            },
            'to' => {
              key: 'form1[0].#subform[1].Date[8]',
              format: 'date'
            }
          },
          'otherEdPreUnemployOverflow' => {
            key: '',
            question_num: 24,
            question_suffix: 'B',
            question_text: 'Type of Education or Training Prior to Unemployability'
          }
        },
        'otherEducationTrainingPostUnemployability' => {
          limit: 1,
          question_num: 25,
          question_text: 'Other Education or Training After Unemployability',
          first_key: 'name',
          'name' => {
            key: 'form1[0].#subform[1].TypeOfEducationOrTraining[0]'
          },
          'dates' => {
            'from' => {
              key: 'form1[0].#subform[1].Date[5]',
              format: 'date'
            },
            'to' => {
              key: 'form1[0].#subform[1].Date[6]',
              format: 'date'
            }
          },
          'otherEdPostUnemployOverflow' => {
            key: '',
            question_num: 25,
            question_suffix: 'B',
            question_text: 'Other Education or Training After Unemployability'
          }
        },
        'doctorsCareDateRanges' => {
          limit: 0,
          question_text: 'DATE(S) OF TREATMENT BY DOCTOR(S)',
          question_num: 10
        },
        'hospitalCareDateRanges' => {
          limit: 0,
          question_text: 'DATE(S) OF HOSPITALIZATION',
          question_num: 13
        },
        'doctorsCareDetails' => {
          limit: 1,
          question_text: 'NAME AND ADDRESS OF DOCTOR(S)',
          question_num: 11,
          first_key: 'value',
          'value' => {
            question_text: 'NAME AND ADDRESS OF DOCTOR(S)',
            question_num: 11,
            key: 'form1[0].#subform[0].NameAndAddressOfDoctors[0]'
          }
        },
        'hospitalCareDetails' => {
          limit: 1,
          question_text: 'NAME AND ADDRESS OF HOSPITAL',
          question_num: 12,
          first_key: 'value',
          'value' => {
            question_text: 'NAME AND ADDRESS OF HOSPITAL',
            question_num: 12,
            key: 'form1[0].#subform[0].NameAndAddressOfHospitals[0]'
          }
        },
        'previousEmployers' => {
          limit: 5,
          question_num: 18,
          question_text: 'Previous Employers',
          first_key: 'nameAndAddress',
          'nameAndAddress' => {
            key: "employerNameAddress[#{ITERATOR}]"
          },
          'typeOfWork' => {
            key: "typeOfWork[#{ITERATOR}]"
          },
          'hoursPerWeek' => {
            key: "hoursPerWeek[#{ITERATOR}]"
          },
          'fromDate' => {
            key: "fromDate[#{ITERATOR}]",
            format: 'date'
          },
          'toDate' => {
            key: "toDate[#{ITERATOR}]",
            format: 'date'
          },
          'timeLostFromIllness' => {
            key: "timeLost[#{ITERATOR}]"
          },
          'mostEarningsInAMonth' => {
            key: "highestGrossEarnings[#{ITERATOR}]"
          },
          'previousEmployerOverflow' => {
            key: '',
            question_text: 'Previous Employer',
            question_num: 18,
            question_suffix: 'A'
          }
        },
        'disabilityAffectEmployFTDate' => {
          'day' => {
            key: 'form1[0].#subform[0].Day[4]'
          },
          'month' => {
            key: 'form1[0].#subform[0].Month[4]'
          },
          'year' => {
            key: 'form1[0].#subform[0].Year[8]'
          }
        },
        'lastWorkedFullTimeDate' => {
          'day' => {
            key: 'form1[0].#subform[0].Day[5]'
          },
          'month' => {
            key: 'form1[0].#subform[0].Month[5]'
          },
          'year' => {
            key: 'form1[0].#subform[0].Year[9]'
          }
        },
        'becameTooDisabledToWorkDate' => {
          'day' => {
            key: 'form1[0].#subform[0].Day[6]'
          },
          'month' => {
            key: 'form1[0].#subform[0].Month[6]'
          },
          'year' => {
            key: 'form1[0].#subform[0].Year[10]'
          }
        },
        'mostEarningsInAYear' => {
          key: 'form1[0].#subform[0].NumericField1[0]'
        },
        'yearOfMostEarnings' => {
          key: 'form1[0].#subform[0].Year[11]'
        },
        'occupationDuringMostEarnings' => {
          key: 'form1[0].#subform[0].OccupationDuringThatYear[0]'
        },
        'preventMilitaryDutiesYes' => {
          key: 'form1[0].#subform[1].CheckBoxYes[4]'
        },
        'preventMilitaryDutiesNo' => {
          key: 'form1[0].#subform[1].CheckBoxNo[4]'
        },
        'past12MonthsEarnedIncome' => {
          key: 'form1[0].#subform[1].NumericField1[4]'
        },
        'currentMonthlyEarnedIncome' => {
          key: 'form1[0].#subform[1].NumericField1[5]'
        },
        'leftLastJobDueToDisabilityYes' => {
          key: 'form1[0].#subform[1].CheckBoxYes[2]'
        },
        'leftLastJobDueToDisabilityNo' => {
          key: 'form1[0].#subform[1].CheckBoxNo[2]'
        },
        'expectDisabilityRetirementYes' => {
          key: 'form1[0].#subform[1].CheckBoxYes[1]'
        },
        'expectDisabilityRetirementNo' => {
          key: 'form1[0].#subform[1].CheckBoxNo[1]'
        },
        'receiveExpectWorkersCompensationYes' => {
          key: 'form1[0].#subform[1].CheckBoxYes[3]'
        },
        'receiveExpectWorkersCompensationNo' => {
          key: 'form1[0].#subform[1].CheckBoxNo[3]'
        },
        'attemptedEmployYes' => {
          key: 'form1[0].#subform[1].CheckBoxYes[5]'
        },
        'attemptedEmployNo' => {
          key: 'form1[0].#subform[1].CheckBoxNo[5]'
        },
        'appliedEmployers' => {
          limit: 3,
          question_text: 'Employers Applied For Work Since Unemployment',
          first_key: 'nameAndAddress',
          'nameAndAddress' => {
            key: "appliedEmployer[#{ITERATOR}]"
          },
          'workType' => {
            key: "workType[#{ITERATOR}]"
          },
          'date' => {
            key: "dateApplied[#{ITERATOR}]",
            format: 'date'
          },
          'appliedEmployerOverflow' => {
            key: '',
            question_text: 'Employer Applied to for Work Since Unemployment',
            question_num: 22,
            question_suffix: 'A'
          }
        },
        'remarks' => {
          key: 'form1[0].#subform[2].Remarks[0]'
        }
      }.freeze

      def merge_fields(_options = {})
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
        expand_ssn
        expand_veteran_dob
        expand_veteran_address
        transform_various_unemployment_fields(@form_data['unemployability'])
        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = "/es/ #{@form_data['signature']}"

        @form_data.except!('unemployability')

        @form_data
      end

      private

      def expand_service_connected_disability(unemployability)
        @form_data['serviceConnectedDisability'] = unemployability['disabilityPreventingEmployment']
      end

      def expand_doctors_care_or_hospitalized(unemployability)
        @form_data['wasHospitalizedYes'] = unemployability['underDoctorHopitalCarePast12M'] == true
        @form_data['wasHospitalizedNo'] = unemployability['underDoctorHopitalCarePast12M'] == false
      end

      def expand_veteran_full_name
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
      end

      def expand_provided_care(provided_care, key)
        return if provided_care.blank?

        expand_provided_care_details(provided_care, key)
        expand_provided_care_date_range(provided_care, key)
      end

      def expand_provided_care_date_range(provided_care, key)
        return if provided_care.empty?

        care_date_ranges = []
        provided_care.each do |care|
          care_date_ranges.push(care['dates']) if care['dates'].present?
        end
        @form_data["#{key}DateRanges"] = care_date_ranges
      end

      def expand_provided_care_details(provided_care, key)
        return if provided_care.empty?

        care_details = []
        provided_care.each do |care|
          details = {
            'value' => care['name'] + "\n#{address_block(care['address'])}"
          }
          care_details.push(details)
        end
        @form_data["#{key}Details"] = care_details
      end

      def expand_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        return if ssn.blank?

        ['', '1', '2'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
        end
      end

      def expand_veteran_dob
        return if @form_data['veteranDateOfBirth'].blank?

        @form_data['veteranDateOfBirth'] = split_date(@form_data['veteranDateOfBirth'])
      end

      def expand_veteran_address
        @form_data['veteranAddress']['country'] = extract_country(@form_data['veteranAddress'])
        @form_data['veteranAddress']['postalCode'] = split_postal_code(@form_data['veteranAddress'])
      end

      def transform_various_unemployment_fields(unemployability)
        return if unemployability.blank?

        collapse_education(unemployability)
        collapse_training(unemployability)
        expand_employment_disability_dates(unemployability)
        expand_income_items(unemployability)
        resolve_yes_no_checkboxes(unemployability)
        resolve_applied_employers(unemployability)
        expand_provided_care(unemployability['doctorProvidedCare'], 'doctorsCare')
        expand_provided_care(unemployability['hospitalProvidedCare'], 'hospitalCare')
        expand_previous_employers(unemployability['previousEmployers'])
        expand_doctors_care_or_hospitalized(unemployability)
        expand_service_connected_disability(unemployability)

        @form_data['remarks'] = unemployability['remarks']
      end

      def collapse_education(unemployability)
        return if unemployability['education'].blank?

        @form_data['education'] = {
          'value' => unemployability['education']
        }
        expand_checkbox_as_hash(@form_data['education'], 'value')
      end

      def collapse_training(unemployability)
        other_training_pre_unemploy = unemployability['otherEducationTrainingPreUnemployability']
        return if other_training_pre_unemploy.blank?

        other_training_pre_unemploy.each do |training|
          overflow = format_training_overflow(training)
          training['otherEdPreUnemployOverflow'] = PdfFill::FormValue.new('', overflow)
        end
        @form_data['otherEducationTrainingPreUnemployability'] = other_training_pre_unemploy

        other_training_post_unemploy = unemployability['otherEducationTrainingPostUnemployability']
        return if other_training_post_unemploy.blank?

        other_training_post_unemploy.each do |training|
          overflow = format_training_overflow(training)
          training['otherEdPostUnemployOverflow'] = PdfFill::FormValue.new('', overflow)
        end
        @form_data['otherEducationTrainingPostUnemployability'] = other_training_post_unemploy
      end

      def format_training_overflow(training)
        return if training.blank?

        overflow = []
        name = training['name'] || ''
        dates = combine_date_ranges([training['dates']])
        overflow.push("#{name}\n#{dates}")
        overflow.compact.join("\n\n")
      end

      def expand_previous_employers(employers)
        return if employers.blank?

        employers.each do |employer|
          overflow = format_previous_employer_overflow(employer)
          employer['previousEmployerOverflow'] = PdfFill::FormValue.new('', overflow)
          compress_previous_employer_info(employer)
        end
        @form_data['previousEmployers'] = employers
      end

      def format_previous_employer_overflow(previous_employer)
        return if previous_employer.blank?

        overflow = []

        format_str = [
          ['Name: ', previous_employer['name']].compact.join(' '),
          ['Address: ', combine_full_address(previous_employer['employerAddress'])].compact.join(' '),
          ['Dates of Employment: ', combine_date_ranges([previous_employer['dates']])].compact.join(' '),
          ['Type of Work: ', previous_employer['typeOfWork']].compact.join(' '),
          ['Hours Per Week: ', previous_employer['hoursPerWeek']].compact.join(' '),
          ['Time Lost From Illness: ', previous_employer['timeLostFromIllness']].compact.join(' '),
          ['Highest Gross Earnings Per Month: ', previous_employer['mostEarningsInAMonth']].compact.join(' ')
        ].compact.join("\n")
        overflow.push(format_str)
        overflow.compact.join("\n\n")
      end

      def compress_previous_employer_info(employer)
        address = combine_full_address(employer['employerAddress'])
        employer['nameAndAddress'] = "#{employer['name']}\n#{address}"
        employer['fromDate'] = employer['dates']['from']
        employer['toDate'] = employer['dates']['to']
        employer.except!('name')
        employer.except!('employerAddress')
        employer.except!('dates')
      end

      def expand_employment_disability_dates(unemployability)
        @form_data['disabilityAffectEmployFTDate'] =
          split_date(unemployability['disabilityAffectedEmploymentFullTimeDate'])
        @form_data['lastWorkedFullTimeDate'] = split_date(unemployability['lastWorkedFullTimeDate'])
        @form_data['becameTooDisabledToWorkDate'] = split_date(unemployability['becameTooDisabledToWorkDate'])
      end

      def expand_income_items(unemployability)
        @form_data['mostEarningsInAYear'] = unemployability['mostEarningsInAYear']
        @form_data['yearOfMostEarnings'] = unemployability['yearOfMostEarnings']
        @form_data['occupationDuringMostEarnings'] = unemployability['occupationDuringMostEarnings']
        @form_data['past12MonthsEarnedIncome'] = unemployability['past12MonthsEarnedIncome']
        @form_data['currentMonthlyEarnedIncome'] = unemployability['currentMonthlyEarnedIncome']
      end

      def resolve_yes_no_checkboxes(unemployability)
        @form_data['preventMilitaryDutiesYes'] = unemployability['disabilityPreventMilitaryDuties'] == true
        @form_data['preventMilitaryDutiesNo'] = unemployability['disabilityPreventMilitaryDuties'] == false
        @form_data['leftLastJobDueToDisabilityYes'] = unemployability['leftLastJobDueToDisability'] == true
        @form_data['leftLastJobDueToDisabilityNo'] = unemployability['leftLastJobDueToDisability'] == false
        @form_data['expectDisabilityRetirementYes'] = unemployability['receiveExpectDisabilityRetirement'] == true
        @form_data['expectDisabilityRetirementNo'] = unemployability['receiveExpectDisabilityRetirement'] == false
        @form_data['receiveExpectWorkersCompensationYes'] = unemployability['receiveExpectWorkersCompensation'] == true
        @form_data['receiveExpectWorkersCompensationNo'] = unemployability['receiveExpectWorkersCompensation'] == false
        @form_data['attemptedEmployYes'] = unemployability['attemptedToObtainEmploymentSinceUnemployability'] == true
        @form_data['attemptedEmployNo'] = unemployability['attemptedToObtainEmploymentSinceUnemployability'] == false
        ed_received_pre = unemployability['receivedOtherEducationTrainingPreUnemployability']
        @form_data['trainingPreDisabledYes'] = ed_received_pre == true
        @form_data['trainingPreDisabledNo'] = ed_received_pre == false
        ed_received_post = unemployability['receivedOtherEducationTrainingPostUnemployability']
        @form_data['trainingPostUnEmployYes'] = ed_received_post == true
        @form_data['trainingPostUnEmployNo'] = ed_received_post == false
      end

      def resolve_applied_employers(unemployability)
        return if unemployability['appliedEmployers'].blank?

        unemployability['appliedEmployers'].each do |employer|
          overflow = format_applied_employer_overflow(employer)
          address = combine_full_address(employer['address'])
          employer['nameAndAddress'] = "#{employer['name']}\n#{address}"
          employer.except!('name')
          employer.except!('address')
          employer['appliedEmployerOverflow'] = PdfFill::FormValue.new('', overflow)
        end
        @form_data['appliedEmployers'] = unemployability['appliedEmployers']
      end

      def format_applied_employer_overflow(applied_employer)
        return if applied_employer.blank?

        overflow = []
        name = "Name: #{applied_employer['name']}" || ''
        address = "Address: #{combine_full_address(applied_employer['address'])}" || ''
        work = "Type of Work: #{applied_employer['workType']}" || ''
        date = "Date Applied: #{applied_employer['date']}" || ''

        overflow.push("#{name}\n#{address}\n#{work}\n#{date}")
        overflow.compact.join("\n\n")
      end
    end
  end
end

# rubocop:enable Metrics/ClassLength
