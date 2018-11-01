# frozen_string_literal: true

module PdfFill
  module Forms
    class Va218940 < FormBase
      include FormHelper

      KEY = {
        'fullName' => {
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
        'veteranAddress' => {
          question_num: 6,
          question_text: 'MAILING ADDRESS',

          'street' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'Number and Street'
          },
          'street2' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]',
            limit: 5,
            question_num: 6,
            question_suffix: 'B',
            question_text: 'Apartment or Unit Number'
          },
          'city' => {
            key: 'form1[0].#subform[0].CurrentMailingAddress_City[0]',
            limit: 18,
            question_num: 6,
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
        'otherTrainingPostUnEmployYes' => {
          key: 'form1[0].#subform[1].CheckBoxYes[7]'
        },
        'otherTrainingPostUnEmployNo' => {
          key: 'form1[0].#subform[1].CheckBoxNo[7]'
        }
      }.freeze

      def merge_fields
        expand_va_file_number
        expand_ssn
        expand_veteran_dob
        expand_claimant_address
        expand_veteran_full_name
        expand_education

        expand_signature(@form_data['veteranFullName'])
        @form_data['signature'] = '/es/ ' + @form_data['signature']

        @form_data['wasHospitalizedYes'] = @form_data['wasHospitalized'] == true
        @form_data['wasHospitalizedNo'] = @form_data['wasHospitalized'] == false

        @form_data['trainingPreDisabledYes'] = @form_data['receivedOtherEducationTrainingPreUnemployability'] == true
        @form_data['trainingPreDisabledNo'] = @form_data['receivedOtherEducationTrainingPreUnemployability'] == false

        @form_data['otherTrainingPostUnEmployYes'] = @form_data['otherEducationTrainingPostUnemployability'] == true
        @form_data['otherTrainingPostUnEmployNo'] = @form_data['otherEducationTrainingPostUnemployability'] == false

        @form_data
      end

      private

      def expand_va_file_number
        va_file_number = @form_data['vaFileNumber']
        return if va_file_number.blank?
        ['', '1'].each do |suffix|
          @form_data["vaFileNumber#{suffix}"] = va_file_number
        end
      end

      def expand_veteran_full_name
        @form_data['fullName'] = extract_middle_i(@form_data, 'fullName')
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

      def expand_claimant_address
        @form_data['veteranAddress']['country'] = extract_country(@form_data['veteranAddress'])
        @form_data['veteranAddress']['postalCode'] = split_postal_code(@form_data['veteranAddress'])
      end

      def expand_education
        education = @form_data['education']
        return if education.blank?

        @form_data['education'] = {
          'value' => education
        }

        expand_checkbox_as_hash(@form_data['education'], 'value')
      end

      def expand_checkbox_as_hash(hash, key)
        value = hash.try(:[], key)
        return if value.blank?

        hash['checkbox'] = {
          value => true
        }
      end
    end
  end
end
