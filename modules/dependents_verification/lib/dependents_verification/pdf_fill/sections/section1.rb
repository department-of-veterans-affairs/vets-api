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
        'veteranFullNameOverflow' => {
          'first' => {
            key: key_name('1', 'VeteranName', 'FirstOverflow'),
            limit: 0,
            question_num: 1,
            question_text: "VETERAN'S FIRST NAME",
            overflow_only: true
          },
          'middleInitial' => {
            key: key_name('1', 'VeteranName', 'MIOverflow'),
            limit: 0,
            question_num: 1,
            question_text: "VETERAN'S MIDDLE INITIAL",
            overflow_only: true
          },
          'last' => {
            key: key_name('1', 'VeteranName', 'LastOverflow'),
            limit: 0,
            question_num: 1,
            question_text: "VETERAN'S LAST NAME",
            overflow_only: true
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
          'unit_number' => {
            key: key_name('5', 'VeteranAddress', 'UnitNumber'),
            limit: 5,
            question_num: 5,
            question_suffix: 'b',
            question_text: 'UNIT NUMBER'
          },
          'city' => {
            key: key_name('5', 'VeteranAddress', 'City'),
            limit: 18,
            question_num: 5,
            question_suffix: 'c',
            question_text: 'CITY'
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
        'veteranAddressOverflow' => {
          'street' => {
            key: key_name('5', 'VeteranAddress', 'StreetOverflow'),
            limit: 0,
            question_num: 5,
            question_suffix: 'a',
            question_text: 'STREET ADDRESS',
            overflow_only: true
          },
          'city' => {
            key: key_name('5', 'VeteranAddress', 'CityOverflow'),
            limit: 0,
            question_num: 5,
            question_suffix: 'b',
            question_text: 'CITY',
            overflow_only: true
          },
          'unit_number' => {
            key: key_name('5', 'VeteranAddress', 'UnitNumberOverflow'),
            limit: 0,
            question_num: 5,
            question_suffix: 'c',
            question_text: 'UNIT NUMBER',
            overflow_only: true
          },
          'country' => {
            key: key_name('5', 'VeteranAddress', 'CountryOverflow'),
            limit: 0,
            question_num: 5,
            question_suffix: 'd',
            question_text: 'COUNTRY',
            overflow_only: true
          },
          'state' => {
            key: key_name('5', 'VeteranAddress', 'StateOverflow'),
            limit: 0,
            question_num: 5,
            question_suffix: 'e',
            question_text: 'STATE',
            overflow_only: true
          },
          'postal_code' => {
            'firstFive' => {
              key: key_name('5', 'VeteranAddress', 'PostalCode', 'FirstOverflow'),
              limit: 0,
              question_num: 5,
              question_suffix: 'f',
              question_text: 'POSTAL CODE - FIRST FIVE',
              overflow_only: true
            },
            'lastFour' => {
              key: key_name('5', 'VeteranAddress', 'PostalCode', 'SecondOverflow'),
              limit: 0,
              question_num: 5,
              question_suffix: 'g',
              question_text: 'POSTAL CODE - LAST FOUR',
              overflow_only: true
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
        'veteranEmailOverflow' => {
          'firstPart' => {
            key: key_name('7', 'VeteranEmail', 'FirstOverflow'),
            limit: 0,
            question_num: 7,
            question_suffix: 'a',
            question_text: 'EMAIL - FIRST PART',
            overflow_only: true
          },
          'secondPart' => {
            key: key_name('7', 'VeteranEmail', 'SecondOverflow'),
            limit: 0,
            question_num: 7,
            question_suffix: 'b',
            question_text: 'EMAIL - SECOND PART',
            overflow_only: true
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

        handle_overflows(form_data)

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
          'unit_number' => address['street2'],
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
          'secondPart' => email[18..]
        }
      end

      # this method handle overflows for address, email, first name, and last name based on new rules.
      # if any part of address overflows, address should appear blank on pdf and show all on overflow page
      # if email overflows, email should appear blank on pdf and show whole email on overflow page
      # if first or last name overflows, truncate the value on pdf and show full value on overflow page.
      def handle_overflows(form_data)
        address_overflow = check_for_multiple_overflow(form_data['veteranAddress'], 'veteranAddress') if form_data['veteranAddress'].present? # rubocop:disable Layout/LineLength
        email_overflow = check_for_multiple_overflow(form_data['veteranEmail'], 'veteranEmail') if form_data['veteranEmail'].present? # rubocop:disable Layout/LineLength

        first_name_overflow = check_for_single_overflow(form_data['veteranFullName']['first'],
                                                        'veteranFullName', 'first')
        last_name_overflow = check_for_single_overflow(form_data['veteranFullName']['last'],
                                                       'veteranFullName', 'last')

        clear_section(form_data, 'veteranAddress') if address_overflow
        clear_section(form_data, 'veteranEmail') if email_overflow

        truncate_section(form_data, %w[veteranFullNameOverflow first], %w[veteranFullName first]) if first_name_overflow
        truncate_section(form_data, %w[veteranFullNameOverflow last], %w[veteranFullName last]) if last_name_overflow

        form_data
      end

      # if any part of the address or email overflows, then the entire section
      # should be blank, and instead the entire section should be printed on the
      # overflow page. This method checks against limits and returns whether there is overflow
      def check_for_multiple_overflow(form_data, key_name)
        attribute_limit = get_sizes(form_data)
        key_limit = get_limits(KEY[key_name])

        attribute_limit.each do |k, v|
          return true if v > key_limit[k]
        end
        false
      end

      # checks the passed in attribute against the limit for the fields passed in.
      def check_for_single_overflow(data, *params)
        data.size > KEY.dig(*params)[:limit]
      end

      # if any part of the address overflows, then the entire address section
      # should be blank, and instead the entire address should be printed on the
      # overflow page. This method clears the relevant data
      def clear_section(form_data, key_name)
        form_data["#{key_name}Overflow"] = form_data[key_name]
        form_data[key_name] = {}
        form_data
      end

      # this truncates the attribute length to the limit of the box on the pdf.
      def truncate_section(form_data, overflow, original)
        deep_set(form_data, overflow, form_data.dig(*original))
        deep_set(form_data, original, form_data.dig(*original)[0..(KEY.dig(*original)[:limit] - 1)])
        form_data
      end

      # this method helps set a value no matter how deep in the has it is.
      # this is useful for when swapping into the overflow fields for a single attribute
      def deep_set(form_data, keys, value)
        keys.reduce(form_data) do |hash, key|
          if key == keys.last
            hash[key] = value
          else
            hash[key] ||= {} # Create a new hash if the key doesn't exist
          end
        end
        form_data # Return the modified hash
      end

      # this method gets the sizes of each attribute in the passed in form_data
      def get_sizes(data, size_map = {})
        data.map do |k, v|
          v = v.to_s if v.is_a?(Numeric)
          if v.is_a?(String)
            size_map[k] = v.size
          elsif v.is_a?(Hash)
            get_sizes(v, size_map)
          end
        end
        size_map
      end

      # this method gets the sizes of the limits in the key for the passed in section name
      def get_limits(data, limit_map = {})
        data.map do |k, v|
          if v[:limit].present?
            limit_map[k] = v[:limit]
          elsif v.is_a?(Hash)
            get_limits(v, limit_map)
          end
        end
        limit_map
      end
    end
  end
end
