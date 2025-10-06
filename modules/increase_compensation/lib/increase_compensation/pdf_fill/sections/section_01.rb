# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section1 < Section
      include Helpers
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting

      # Section configuration hash
      KEY = {
        'veteranFullName' => {
          'first' => {
            limit: 12,
            question_num: 1,
            question_label: "Veteran's First Name",
            question_text: 'VETERAN\'S FIRST NAME',
            key: 'form1[0].#subform[0].VeteransFirstName[0]'
          },
          'middle' => {
            limit: 1,
            question_num: 1,
            key: 'form1[0].#subform[0].VeteransMiddleInitial[0]'
          },
          'last' => {
            limit: 18,
            question_num: 1,
            question_label: "Veteran's Last Name",
            question_text: 'VETERAN\'S LAST NAME',
            key: 'form1[0].#subform[0].VeteransLastName[0]'
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            question_num: 2,
            limit: 3,
            key: 'form1[0].#subform[0].SSNFirstThreeNumbers[0]'
          },
          'second' => {
            question_num: 2,
            limit: 2,
            key: 'form1[0].#subform[0].SSNSecondTwoNumbers[0]'
          },
          'third' => {
            limit: 3,
            question_num: 2,
            key: 'form1[0].#subform[0].SSNLastFourNumbers[0]'
          }
        },
        'vaFileNumber' => {
          question_num: 3,
          limit: 9,
          key: 'form1[0].#subform[0].VAFileNumber[0]'
        },
        'veteranDateOfBirth' => {
          'month' => {
            question_num: 4,
            limit: 2,
            key: 'form1[0].#subform[0].Month[0]'
          },
          'day' => {
            question_num: 4,
            limit: 2,
            key: 'form1[0].#subform[0].Day[0]'
          },
          'year' => {
            question_num: 4,
            limit: 4,
            key: 'form1[0].#subform[0].Year[0]'
          }
        },
        'veteranAddress' => {
          question_num: 5,
          'street' => {
            limit: 30,
            question_label: 'Mailing Address Number And Street',
            question_text: 'MAILING ADDRESS NUMBER AND STREET',
            key: 'form1[0].#subform[0].CurrentMailingAddress_NumberAndStreet[0]'
          },
          'street2' => {
            limit: 5,
            question_label: 'Mailing Address Apt/Unit',
            question_text: 'MAILING ADDRESS APT/UNIT',
            key: 'form1[0].#subform[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]'
          },
          'city' => {
            limit: 18,
            question_label: 'Mailing Address City',
            question_text: 'MAILING ADDRESS CITY',
            key: 'form1[0].#subform[0].CurrentMailingAddress_City[0]'
          },
          'state' => {
            limit: 2,
            key: 'form1[0].#subform[0].CurrentMailingAddress_StateOrProvince[0]'
          },
          'country' => {
            limit: 2,
            key: 'form1[0].#subform[0].CurrentMailingAddress_Country[0]'
          },
          'postalCode' => {
            'firstFive' => {
              limit: 5,
              key: 'form1[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            },
            'lastFour' => {
              limit: 4,
              question_label: 'Postal Code - Last Four',
              question_text: 'POSTAL CODE - LAST FOUR',
              key: 'form1[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
            }
          }
        },
        'electronicCorrespondance' => {
          question_num: 6,
          key: 'form1[0].#subform[0].CheckBox1[0]'
          #  value: 1 or 0
        },
        'emailAddresses' => {
          # limit: 32,
          # ? is it 2 lines? or is it 2 email addresses?
          question_num: 6,
          question_label: "Veteran's E-Mail Address",
          question_text: 'VETERAN\'S E-MAIL ADDRESS',
          'email1' => {
            limit: 17,
            question_num: 6,
            key: 'form1[0].#subform[0].E_Mail_Address_If_Applicable[0]'
          },
          'emai2' => {
            limit: 17,
            question_num: 6,
            key: 'form1[0].#subform[0].E_Mail_Address_If_Applicable[1]'
          }
        },
        'veteranPhone' => {
          question_num: 7,
          'areaCode' => {
            limit: 3,
            key: 'form1[0].#subform[0].AreaCode[0]'
          },
          'firstThree' => {
            limit: 3,
            key: 'form1[0].#subform[0].FirstThreeNumbers[0]'
          },
          'lastFour' => {
            limit: 4,
            key: 'form1[0].#subform[0].LastFourNumbers[0]'
          }
        },
        'internationalPhone' => {
          question_num: 7,
          # limit: 30,
          # question_num: 2,
          # question_suffix: 'C',
          question_label: 'International Phone Number',
          question_text: 'International Phone Number',
          # key: 'form1[0].#subform[48].International_Phone_Number[0]'
          key: 'form1[0].#subform[0].International_Telephone_Number_If_Applicable[0]'
        }
      }.freeze

      def expand(form_data = {})
        # beacuse of how the data is recieved in the form object
        if form_data['veteranSocialSecurityNumber'].is_a? String
          f, s, t = form_data['veteranSocialSecurityNumber'].split('-')
          form_data['veteranSocialSecurityNumber'] = {}
          form_data['veteranSocialSecurityNumber']['first'] = f
          form_data['veteranSocialSecurityNumber']['second'] = s
          form_data['veteranSocialSecurityNumber']['third'] = t
        end

        if form_data['veteranPhone']
          phone = expand_phone_number(form_data['veteranPhone'])
          form_data['veteranPhone'] = {}
          form_data['veteranPhone']['areaCode'] = phone['phone_area_code']
          form_data['veteranPhone']['firstThree'] = phone['phone_first_three_numbers']
          form_data['veteranPhone']['lastFour'] = phone['phone_last_four_numbers']
        end
      end
    end
  end
end
