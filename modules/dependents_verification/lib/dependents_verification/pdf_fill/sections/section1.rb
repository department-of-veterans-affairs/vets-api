# frozen_string_literal: true

require 'dependents_verification/pdf_fill/section'

module DependentsVerification
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section1 < Section
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting
      # Section configuration hash
      KEY = {
        # 1
        'veteranFullName' => {
          'first' => {
            key: key_name('1', 'VeteranName', 'First'),
            limit: 12,
            question_num: 1,
            question_text: "VETERAN'S FIRST NAME"
          },
          'middleInitial' => {
            key: key_name('1', 'VeteranName', 'MI'),
            limit: 1,
            question_num: 1,
            question_text: "VETERAN'S MIDDLE INITIAL"
          },
          'last' => {
            key: key_name('1', 'VeteranName', 'Last'),
            limit: 18,
            question_num: 1,
            question_text: "VETERAN'S LAST NAME"
          }
        },
        # 2
        'veteranSSN' => {
          'first' => {
            key: key_name('2', 'VeteranSSN', 'First'),
            limit: 3
          },
          'second' => {
            key: key_name('2', 'VeteranSSN', 'Middle'),
            limit: 2
          },
          'third' => {
            key: key_name('2', 'VeteranSSN', 'Last'),
            limit: 4
          }
        },
        # 3
        'veteranFileNumber' => {
          key: key_name('3', 'VeteranFileNumber'),
          limit: 9,
          question_num: 3,
          question_text: 'VA FILE NUMBER'
        },
        # 4
        'veteranDOB' => {
          'month' => {
            key: key_name('4', 'VeteranDOB', 'Month'),
            limit: 2,
            question_num: 4,
            question_suffix: 'a',
            question_text: 'DATE OF BIRTH - MONTH'
          },
          'day' => {
            key: key_name('4', 'VeteranDOB', 'Day'),
            limit: 2,
            question_num: 4,
            question_suffix: 'b',
            question_text: 'DATE OF BIRTH - DAY'
          },
          'year' => {
            key: key_name('4', 'VeteranDOB', 'Year'),
            limit: 4,
            question_num: 4,
            question_suffix: 'c',
            question_text: 'DATE OF BIRTH - YEAR'
          }
        },
        # 5
        'veteranAddress' => {
          'street' => {
            key: key_name('5', 'VeteranAddress', 'Street'),
            limit: 30,
            question_num: 5,
            question_suffix: 'a',
            question_text: 'STREET ADDRESS'
          },
          'city' => {
            key: key_name('5', 'VeteranAddress', 'City'),
            limit: 18,
            question_num: 5,
            question_suffix: 'b',
            question_text: 'CITY'
          },
          'unit_number' => {
            key: key_name('5', 'VeteranAddress', 'UnitNumber'),
            limit: 5,
            question_num: 5,
            question_suffix: 'c',
            question_text: 'UNIT NUMBER'
          },
          'country' => {
            key: key_name('5', 'VeteranAddress', 'Country'),
            limit: 2,
            question_num: 5,
            question_suffix: 'd',
            question_text: 'COUNTRY'
          },
          'state' => {
            key: key_name('5', 'VeteranAddress', 'State'),
            limit: 2,
            question_num: 5,
            question_suffix: 'e',
            question_text: 'STATE'
          },
          'postal_code' => {
            'firstFive' => {
              key: key_name('5', 'VeteranAddress', 'PostalCode', 'First'),
              limit: 5,
              question_num: 5,
              question_suffix: 'f',
              question_text: 'POSTAL CODE - FIRST FIVE'
            },
            'lastFour' => {
              key: key_name('5', 'VeteranAddress', 'PostalCode', 'Second'),
              limit: 4,
              question_num: 5,
              question_suffix: 'g',
              question_text: 'POSTAL CODE - LAST FOUR'
            }
          }
        },
        # 6
        'veteranPhone' => {
          'phone_area_code' => {
            key: key_name('6', 'VeteranPhone', 'First'),
            limit: 3,
            question_num: 6,
            question_suffix: 'a',
            question_text: 'PHONE - AREA CODE'
          },
          'phone_first_three_numbers' => {
            key: key_name('6', 'VeteranPhone', 'Second'),
            limit: 3,
            question_num: 6,
            question_suffix: 'b',
            question_text: 'PHONE - FIRST THREE NUMBERS'
          },
          'phone_last_four_numbers' => {
            key: key_name('6', 'VeteranPhone', 'Third'),
            limit: 4,
            question_num: 6,
            question_suffix: 'c',
            question_text: 'PHONE - LAST FOUR NUMBERS'
          }
        },
        # 6
        'veteranInternationalPhone' => {
          key: key_name('6', 'VeteranPhone', 'International')
        },
        # 7
        'veteranEmail' => {
          'firstPart' => {
            key: key_name('7', 'VeteranEmail', 'First'),
            limit: 18,
            question_num: 7,
            question_suffix: 'a',
            question_text: 'EMAIL - FIRST PART'
          },
          'secondPart' => {
            key: key_name('7', 'VeteranEmail', 'Second'),
            limit: 18,
            question_num: 7,
            question_suffix: 'b',
            question_text: 'EMAIL - SECOND PART'
          }
        },
        'veteranEmailAgree' => {
          key: key_name('7', 'VeteranEmail', 'Agree')
        }
      }.freeze

      ##
      # Expands the veteran's information by extracting the full name and assigning it to the form data.
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        veteran_information = form_data['veteranInformation'] || {}

        full_name = extract_middle_i(veteran_information, 'fullName') || {}
        full_name.delete('middle')

        form_data['veteranFullName'] = full_name
        form_data['veteranSSN'] = split_ssn(veteran_information['ssn'])
        form_data['veteranFileNumber'] = veteran_information['vaFileNumber']
        form_data['veteranDOB'] = split_date(veteran_information['birthDate'])
        form_data['veteranAddress'] = expand_address(form_data['address'])
        form_data['veteranEmail'] = expand_email(form_data['email'])
        form_data['veteranEmailAgree'] = select_checkbox(form_data['electronicCorrespondence'])

        expand_phone_numbers(form_data)
        form_data
      end

      def expand_phone_numbers(form_data)
        form_data['veteranPhone'] = expand_phone_number(form_data['phone']) if us_phone?(form_data['phone'])

        if international_phone?(form_data['internationalPhone'])
          form_data['veteranInternationalPhone'] = form_data['internationalPhone']
        end
      end

      def international_phone?(phone_number)
        phone_number.present? && phone_number.length > 10
      end

      def us_phone?(phone_number)
        phone_number.present? && phone_number.length == 10
      end

      def expand_address(address)
        return if address.blank?

        {
          'street' => address['street'],
          'unit_number' => address['unitNumber'],
          'city' => address['city'],
          'state' => address['state'],
          'postal_code' => split_postal_code(address),
          'country' => extract_country(address)
        }
      end

      def expand_email(email)
        return if email.blank?

        {
          'firstPart' => email[0..17],
          'secondPart' => email[18..35]
        }
      end
    end
  end
end
