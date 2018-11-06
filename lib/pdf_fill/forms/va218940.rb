# frozen_string_literal: true

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
          key: 'form1[0].#subform[2].DateSigned[0]'
        },
        'serviceConnectedDisability' => {
          key: 'form1[0].#subform[0].ServiceConnectedDisability[0]',
          limit: 90,
          question_num: 2,
          question_text: 'SERVICE CONNECTED DISABILITY'
        },
        'wasHospitalizedYes' => {
          key: 'form1[0].#subform[0].CheckBoxYes[0]'
        },
        'wasHospitalizedNo' => {
          key: 'form1[0].#subform[0].CheckBoxNo[0]'
        },
        'witness1Signature' => {
          key: 'form1[0].#subform[2].Signature[0]'
        },
        'witness1Address' => {
          key: 'form1[0].#subform[2].AddressofWitness[1]'
        },
        'witness2Signature' => {
          key: 'form1[0].#subform[2].Signature[1]'
        },
        'witness2Address' => {
          key: 'form1[0].#subform[2].AddressofWitness[0]'
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
          'name' => {
            key: 'form1[0].#subform[1].TypeOfEducationOrTraining[1]'
          },
          'dates' => {
            'from' => {
              key: 'form1[0].#subform[1].Date[7]'
            },
            'to' => {
              key: 'form1[0].#subform[1].Date[8]'
            }
          }
        },
        'otherEducationTrainingPostUnemployability' => {
          limit: 1,
          'name' => {
            key: 'form1[0].#subform[1].TypeOfEducationOrTraining[0]'
          },
          'dates' => {
            'from' => {
              key: 'form1[0].#subform[1].Date[5]'
            },
            'to' => {
              key: 'form1[0].#subform[1].Date[6]'
            }
          }
        },
        'preDisTrainOverflow' => {
          key: '',
          question_text: 'Pre-Disability Education or Training',
          question_num: 24,
          question_suffix: 'B'
        },
        'postDisTrainOverflow' => {
          key: '',
          question_text: 'Post-Disability Education or Training',
          question_num: 25,
          question_suffix: 'B'
        },
        'doctorsCareDateRanges' => {
          limit: 6,
          question_text: 'DATE(S) OF TREATMENT BY DOCTOR(S)',
          question_num: 10,
          'from' => {
            question_num: 10,
            question_text: 'From:',
            key: "form1[0].#subform[0].DoctorsCareDateFrom[#{ITERATOR}]"
          },
          'to' => {
            question_num: 10,
            question_text: 'To:',
            key: "form1[0].#subform[0].DoctorsCareDateTo[#{ITERATOR}]"
          }
        },
        'hospitalCareDateRanges' => {
          limit: 6,
          question_text: 'DATE(S) OF HOSPITALIZATION',
          question_num: 13,
          'from' => {
            question_num: 13,
            question_text: 'From:',
            key: "form1[0].#subform[0].HospitalCareDateFrom[#{ITERATOR}]"
          },
          'to' => {
            question_num: 13,
            question_text: 'To:',
            key: "form1[0].#subform[0].HospitalCareDateTo[#{ITERATOR}]"
          }
        },
        'doctorsCareDetails' => {
          limit: 1,
          'value' => {
            question_text: 'NAME AND ADDRESS OF DOCTOR(S)',
            question_num: 11,
            key: "form1[0].#subform[0].NameAndAddressOfDoctors[#{ITERATOR}]"
          }
        },
        'hospitalCareDetails' => {
          limit: 1,
          'value' => {
            question_text: 'NAME AND ADDRESS OF HOSPITAL',
            question_num: 12,
            key: "form1[0].#subform[0].NameAndAddressOfHospitals[#{ITERATOR}]"
          }
        }
      }.freeze

      def merge_fields
        @form_data['veteranFullName'] = extract_middle_i(@form_data, 'veteranFullName')
        expand_ssn
        expand_veteran_dob
        expand_veteran_address
        collapse_education(@form_data['unemployability'])
        collapse_training(@form_data['unemployability'])
        expand_doctors_care_or_hospitalized
        expand_service_connected_disability
        expand_provided_care(@form_data['unemployability']['doctorProvidedCare'], 'doctorsCare')
        expand_provided_care(@form_data['unemployability']['hospitalProvidedCare'], 'hospitalCare')

        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = '/es/ ' + @form_data['signature']

        @form_data.except!('unemployability')
      end

      private

      def expand_service_connected_disability
        @form_data['serviceConnectedDisability'] = @form_data['unemployability']['disabilityPreventingEmployment']
      end

      def expand_doctors_care_or_hospitalized
        @form_data['wasHospitalizedYes'] = @form_data['unemployability']['underDoctorHopitalCarePast12M'] == true
        @form_data['wasHospitalizedNo'] = @form_data['unemployability']['underDoctorHopitalCarePast12M'] == false
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
        veteran_date_of_birth = @form_data['veteranDateOfBirth']
        return if veteran_date_of_birth.blank?
        @form_data['veteranDateOfBirth'] = split_date(veteran_date_of_birth)
      end

      def expand_veteran_address
        @form_data['veteranAddress']['country'] = extract_country(@form_data['veteranAddress'])
        @form_data['veteranAddress']['postalCode'] = split_postal_code(@form_data['veteranAddress'])
      end

      def collapse_education(hash)
        return if hash.blank?
        return if hash['education'].blank?
        @form_data['education'] = {
          'value' => hash['education']
        }
        expand_checkbox_as_hash(@form_data['education'], 'value')
      end

      def collapse_training(hash)
        return if hash.blank?

        ed_received_pre = hash['receivedOtherEducationTrainingPreUnemployability']
        if ed_received_pre
          @form_data['trainingPreDisabledYes'] = true
        else
          @form_data['trainingPreDisabledNo'] = true
        end

        other_training_pre_unemploy = hash['otherEducationTrainingPreUnemployability']
        @form_data['otherEducationTrainingPreUnemployability'] = other_training_pre_unemploy
        format_training_overflow(other_training_pre_unemploy, 'preDisTrainOverflow')

        ed_received_post = hash['receivedOtherEducationTrainingPostUnemployability']
        if ed_received_post
          @form_data['trainingPostUnEmployYes'] = true
        else
          @form_data['trainingPostUnEmployNo'] = true
        end

        other_training_post_unemploy = hash['otherEducationTrainingPostUnemployability']
        @form_data['otherEducationTrainingPostUnemployability'] = other_training_post_unemploy
        format_training_overflow(other_training_post_unemploy, 'postDisTrainOverflow')
      end

      def format_training_overflow(training, key)
        return if training.blank?
        overflow = []
        training.each do |edu|
          name = edu['name'] || ''
          dates = combine_date_ranges([edu['dates']])
          overflow.push(name + "\n" + dates)
        end

        overflow.compact.join("\n\n")
        @form_data[key] = PdfFill::FormValue.new('', overflow)
      end
    end
  end
end
