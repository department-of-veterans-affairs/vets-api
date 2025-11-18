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
          'middleinitial' => {
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
            key: 'form1[0].#subform[0].SSNFirstThreeNumbers[0]'
          },
          'second' => {
            question_num: 2,
            key: 'form1[0].#subform[0].SSNSecondTwoNumbers[0]'
          },
          'third' => {
            question_num: 2,
            key: 'form1[0].#subform[0].SSNLastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber1' => {
          'first' => {
            key: 'form1[0].#subform[1].SSNFirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[1].SSNSecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[1].SSNLastFourNumbers[1]'
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'form1[0].#subform[2].SSNFirstThreeNumbers[2]'
          },
          'second' => {
            key: 'form1[0].#subform[2].SSNSecondTwoNumbers[2]'
          },
          'third' => {
            key: 'form1[0].#subform[2].SSNLastFourNumbers[2]'
          }
        },
        'veteranSocialSecurityNumber3' => {
          'first' => {
            key: 'form1[0].#subform[4].SSNFirstThreeNumbers[3]'
          },
          'second' => {
            key: 'form1[0].#subform[4].SSNSecondTwoNumbers[3]'
          },
          'third' => {
            key: 'form1[0].#subform[4].SSNLastFourNumbers[3]'
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
            question_num: 5,
            question_label: 'Mailing Address Number And Street',
            question_text: 'MAILING ADDRESS NUMBER AND STREET',
            key: 'form1[0].#subform[0].CurrentMailingAddress_NumberAndStreet[0]'
          },
          'street2' => {
            question_num: 5,
            question_label: 'Mailing Address Apt/Unit',
            question_text: 'MAILING ADDRESS APT/UNIT',
            key: 'form1[0].#subform[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]'
          },
          'city' => {
            limit: 18,
            question_num: 5,
            question_label: 'Mailing Address City',
            question_text: 'MAILING ADDRESS CITY',
            key: 'form1[0].#subform[0].CurrentMailingAddress_City[0]'
          },
          'state' => {
            question_num: 5,
            limit: 2,
            key: 'form1[0].#subform[0].CurrentMailingAddress_StateOrProvince[0]'
          },
          'country' => {
            question_num: 5,
            key: 'form1[0].#subform[0].CurrentMailingAddress_Country[0]'
          },
          'postalCode' => {
            question_num: 5,
            'firstFive' => {
              question_num: 5,
              limit: 5,
              key: 'form1[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            },
            'lastFour' => {
              question_num: 5,
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
        'emailAddress' => {
          question_num: 6,
          question_label: "Veteran's E-Mail Address",
          question_text: 'VETERAN\'S E-MAIL ADDRESS',
          'email1' => {
            question_num: 6,
            question_label: "Veteran's E-Mail Address",
            question_text: 'VETERAN\'S E-MAIL ADDRESS',
            limit: 17,
            key: 'form1[0].#subform[0].E_Mail_Address_If_Applicable[0]'
          },
          'email2' => {
            question_num: 6,
            limit: 17,
            key: 'form1[0].#subform[0].E_Mail_Address_If_Applicable[1]'
          }
        },
        'veteranPhone' => {
          question_num: 7,
          'phone_area_code' => {
            limit: 3,
            key: 'form1[0].#subform[0].AreaCode[0]'
          },
          'phone_first_three_numbers' => {
            limit: 3,
            key: 'form1[0].#subform[0].FirstThreeNumbers[0]'
          },
          'phone_last_four_numbers' => {
            limit: 4,
            key: 'form1[0].#subform[0].LastFourNumbers[0]'
          }
        },
        'internationalPhone' => {
          question_num: 7,
          limit: 19,
          question_label: 'International Phone Number',
          question_text: 'International Phone Number',
          key: 'form1[0].#subform[0].International_Telephone_Number_If_Applicable[0]'
        }
      }.freeze

      def expand(form_data = {})
        form_data['veteranFullName'] = extract_middle_i(form_data, 'veteranFullName')
        form_data['veteranPhone'] = expand_phone_number(form_data['veteranPhone']) if form_data['veteranPhone'].present?
        form_data['veteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])
        form_data['veteranSocialSecurityNumber1'] = form_data['veteranSocialSecurityNumber']
        form_data['veteranSocialSecurityNumber2'] = form_data['veteranSocialSecurityNumber']
        form_data['veteranSocialSecurityNumber3'] = form_data['veteranSocialSecurityNumber']
        form_data['veteranDateOfBirth'] = split_date(form_data['dateOfBirth'])
        if form_data['veteranAddress'].present?
          form_data['veteranAddress']['postalCode'] = split_postal_code(form_data['veteranAddress'])
        end
        form_data['electronicCorrespondance'] = form_data['electronicCorrespondance'] ? 1 : 0
        # overflow text to next line if under total limit, otherwise save to one line for overflow page
        form_data['emailAddress'] = if form_data['email'].present? && form_data['email'].length > 34
                                      { 'email1' => form_data['email'] }
                                    else
                                      two_line_overflow(form_data['email'], 'email', 17)
                                    end
      end
    end
  end
end
