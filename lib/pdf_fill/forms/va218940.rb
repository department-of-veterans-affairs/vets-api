# frozen_string_literal: true

module PdfFill
  module Forms
    class Va218940 < FormBase
      include FormHelper

      KEY = {
        'veteran' => {
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
          'mailingAddress' => {
            question_num: 6,
            question_text: 'MAILING ADDRESS',
            'addressLine1' => {
              key: 'form1[0].#subform[0].CurrentMailingAddress_NumberAndStreet[0]',
              limit: 30,
              question_num: 6,
              question_suffix: 'A',
              question_text: 'Number and Street'
            },
            'addressLine2' => {
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
            'zipCode' => {
              'firstFive' => {
                key: 'form1[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
              },
              'lastFour' => {
                key: 'form1[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
              }
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
        }
      }.freeze

      def merge_fields
        expand_ssn
        expand_veteran_dob
        expand_veteran_address
        expand_veteran_full_name

        # expand_signature(@form_data['veteranFullName'])
        # @form_data['signature'] = '/es/ ' + @form_data['signature']

        # @form_data['wasHospitalizedYes'] = @form_data['wasHospitalized'] == true
        # @form_data['wasHospitalizedNo'] = @form_data['wasHospitalized'] == false

        @form_data
      end

      private

      def expand_veteran_full_name
        @form_data['veteran']['fullName'] = extract_middle_i(@form_data['veteran'], 'fullName')
      end

      def expand_ssn
        ssn = @form_data['veteran']['socialSecurityNumber']
        return if ssn.blank?
        ['', '1', '2'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
        end
      end

      def expand_veteran_dob
        veteran_date_of_birth = @form_data['veteran']['dateOfBirth']
        return if veteran_date_of_birth.blank?
        @form_data['veteranDateOfBirth'] = split_date(veteran_date_of_birth)
      end

      def expand_veteran_address
        @form_data['veteran']['mailingAddress']['country'] = extract_country(@form_data['veteran']['mailingAddress'])
        @form_data['veteran']['mailingAddress']['zipCode'] =
          split_postal_code(@form_data['veteran']['mailingAddress'], 'zipCode')
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
