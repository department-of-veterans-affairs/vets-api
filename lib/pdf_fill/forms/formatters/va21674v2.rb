# frozen_string_literal: true

require 'pdf_fill/forms/formatters/base'

module PdfFill
  module Forms
    module Formatters
      class Va21674v2 < Base
        class << self
          INCOME_CHAR_LIMIT = 8
          NETWORTH_CHAR_LIMIT = 10

          # Handles phone number formatting for pdf fields
          #
          # @param phone_number [String, Integer] The phone number to format
          # @return [Hash] A hash with area code, first three numbers, and last four numbers
          def expand_phone_number(phone_number)
            phone_number = phone_number.to_s.delete('^0-9')
            {
              'phone_area_code' => phone_number[0..2] || '',
              'phone_first_three_numbers' => phone_number[3..5] || '',
              'phone_last_four_numbers' => phone_number[6..9] || ''
            }
          end

          ##
          # Converts program type codes to human-readable program names
          #
          # @param parent_object [Hash] Hash with program type keys (ch35, fry, feca, other)
          # @return [String, nil] Comma-separated list of program names, or nil if no programs selected
          #
          # @example
          #   get_program({ 'ch35' => true, 'fry' => true })
          #   # => "Chapter 35, Fry Scholarship"
          #
          def get_program(parent_object)
            return nil if parent_object.blank?

            type_mapping = {
              'ch35' => 'Chapter 35',
              'fry' => 'Fry Scholarship',
              'feca' => 'FECA',
              'other' => 'Other Benefit'
            }
            # sanitize object of false values
            parent_object.compact_blank!

            parent_object.map { |key, _value| type_mapping[key] }.join(', ')
          end

          # rubocop:disable Metrics/MethodLength
          # Formats checkboxes and radio buttons in the dependents pdf
          #
          # @param dependents_application [Hash] The dependents application data
          # @return [void]
          def format_checkboxes(dependents_application)
            students_information = dependents_application['student_information']
            if students_information.present?
              students_information.each do |student_information|
                was_married = student_information['was_married']
                school_information = student_information['school_information']
                student_information['was_married'] = {
                  'was_married_yes' => select_checkbox(was_married),
                  'was_married_no' => select_checkbox(!was_married)
                }

                is_paid = student_information['tuition_is_paid_by_gov_agency']
                student_information['tuition_is_paid_by_gov_agency'] = {
                  'is_paid_yes' => select_checkbox(is_paid),
                  'is_paid_no' => select_checkbox(!is_paid)
                }

                is_full_time = school_information['student_is_enrolled_full_time']
                school_information['student_is_enrolled_full_time'] = {
                  'full_time_yes' => select_checkbox(is_full_time),
                  'full_time_no' => select_checkbox(!is_full_time)
                }

                did_attend = school_information['student_did_attend_school_last_term']
                school_information['student_did_attend_school_last_term'] = {
                  'did_attend_yes' => select_checkbox(did_attend),
                  'did_attend_no' => select_checkbox(!did_attend)
                }

                is_school_accredited = school_information['is_school_accredited']
                school_information['is_school_accredited'] = {
                  'is_school_accredited_yes' => select_radio_button(is_school_accredited),
                  'is_school_accredited_no' => select_radio_button(!is_school_accredited)
                }
              end
            end
          end
          # rubocop:enable Metrics/MethodLength

          ##
          # Splits earnings values into PDF field format segments
          #
          # Converts numeric earnings values into the format required by the PDF form,
          # splitting each value into first (2 digits), second (3 digits), and third (2 digits) segments.
          #
          # @param parent_object [Hash] Hash containing earnings keys to process
          # @return [Hash, nil] Modified parent object with split values, or nil if blank
          def split_earnings(parent_object)
            return if parent_object.blank?

            keys_to_process = %w[
              earnings_from_all_employment annual_social_security_payments
              other_annuities_income all_other_income
            ]
            keys_to_process.each do |key|
              value = parent_object[key]
              next if value.blank?

              # Values over 8 characters (pdf field limit) are added to overflow
              next if value.length > 8

              split_value = value.split('.')
              cents = split_value[1] || '00'
              dollars = split_value[0].rjust(5, '0')
              parent_object[key] = {
                'first' => dollars[0..1],
                'second' => dollars[2..4],
                'third' => cents
              }
            end
            parent_object
          end

          ##
          # Splits net worth values into PDF field format segments
          #
          # Converts numeric net worth values (savings, securities, real estate, etc.) into
          # the format required by the PDF form, splitting each into 4 segments for different
          # magnitude ranges.
          #
          # @param parent_object [Hash] Hash containing net worth keys to process
          # @return [Hash, nil] Modified parent object with split values, or nil if blank
          def split_networth_information(parent_object)
            return if parent_object.blank?

            keys_to_process = %w[savings securities real_estate other_assets total_value]
            keys_to_process.each do |key|
              value = parent_object[key]
              next if value.blank?
              # Values over 10 characters (pdf field limit) are added to overflow
              next if value.length > 10

              split_value = value.split('.')
              cents = split_value[1] || '00'
              dollars = split_value[0].rjust(7, '0')

              parent_object[key] = {
                'first' => dollars[0],
                'second' => dollars[1..3],
                'third' => dollars[4..6],
                'last' => cents
              }
            end
            parent_object
          end

          # Checks for overflow in student current/expected earnings section
          #
          # @param student_earnings [Hash] The student earnings data to check for overflow
          # @return [Hash] A hash indicating which fields have overflowed
          def check_earnings_overflow(student_earnings)
            all_employment, annual_ss, other_annuities, all_other_income = student_earnings.values_at(
              'earnings_from_all_employment',
              'annual_social_security_payments',
              'other_annuities_income',
              'all_other_income'
            )
            {
              earnings_from_all_employment: check_for_single_overflow(all_employment, INCOME_CHAR_LIMIT),
              annual_social_security_payments: check_for_single_overflow(annual_ss, INCOME_CHAR_LIMIT),
              other_annuities_income: check_for_single_overflow(other_annuities, INCOME_CHAR_LIMIT),
              all_other_income: check_for_single_overflow(all_other_income, INCOME_CHAR_LIMIT)
            }
          end

          # Checks for overflow in student networth information section
          #
          # @param student_networth [Hash] The student networth data to check for overflow
          # @return [Hash] A hash indicating which fields have overflowed
          def check_networth_overflow(student_networth)
            savings, securities, real_estate, other_assets, total_value = student_networth.values_at(
              'savings',
              'securities',
              'real_estate',
              'other_assets',
              'total_value'
            )
            {
              savings: check_for_single_overflow(savings, NETWORTH_CHAR_LIMIT),
              securities: check_for_single_overflow(securities, NETWORTH_CHAR_LIMIT),
              real_estate: check_for_single_overflow(real_estate, NETWORTH_CHAR_LIMIT),
              other_assets: check_for_single_overflow(other_assets, NETWORTH_CHAR_LIMIT),
              total_value: check_for_single_overflow(total_value, NETWORTH_CHAR_LIMIT)
            }
          end

          # checks the passed in attribute against the limit for the fields passed in
          #
          # @param data [String, Hash, nil] The data to check for overflow
          # @param size [Integer] The character limit for the field
          # @return [Boolean] Whether the data exceeds the character limit
          def check_for_single_overflow(data, size)
            return false if data.is_a?(Hash) || data.blank?

            data.size > size
          end

          # override from form_helper
          #
          # @param value [Boolean] The value to convert to a checkbox state
          # @return [String, nil] 'On' if true, nil if false
          def select_checkbox(value)
            value ? 'On' : nil
          end

          # override from form_helper
          #
          # @param value [Boolean] The value to convert to a radio button state
          # @return [Integer, nil] 0 if true, nil if false
          def select_radio_button(value)
            value ? 0 : nil
          end

          # Handles overflows for student earnings and networth information
          #
          # @param form_data [Hash] The form data hash to process
          # @return [void]
          def handle_overflows(form_data)
            student_information = form_data.dig('dependents_application', 'student_information', 0)
            return unless student_information

            expected_earnings_key = 'student_expected_earnings_next_year'
            earnings_key = 'student_earnings_from_school_year'
            networth_key = 'student_networth_information'

            student_expected_earnings = student_information[expected_earnings_key]
            student_earnings = student_information[earnings_key]
            student_networth = student_information[networth_key]

            # Check for overflows and handle each section
            if student_expected_earnings.present?
              handle_earnings_overflow(form_data, student_expected_earnings,
                                       expected_earnings_key)
            end
            if student_earnings.present?
              handle_earnings_overflow(form_data, student_earnings,
                                       earnings_key)
            end
            handle_networth_overflow(form_data, student_networth) if student_networth.present?
          end

          # Handles overflow for student current and expected earnings sections
          #
          # @param form_data [Hash] The form data hash to process
          # @param student_earnings [Hash] The student earnings data to check for overflow
          # @param form_key [String] The key in the form data corresponding to the earnings section
          # @return [void]
          def handle_earnings_overflow(form_data, student_earnings, form_key)
            earnings_overflow_hash = check_earnings_overflow(student_earnings)

            # If any field overflows, move all fields to overflow page and clear originals
            if earnings_overflow_hash.values.any?
              form_data["#{form_key}_overflow"] ||= {}

              %w[earnings_from_all_employment annual_social_security_payments other_annuities_income
                 all_other_income].each do |field|
                original_value = student_earnings[field]
                if earnings_overflow_hash[field.to_sym]
                  # Copy original string value to overflow
                  form_data["#{form_key}_overflow"][field] = original_value
                  # Set original field to 'See add'l info' text similar to rest of overflow handling on 686c-674
                  form_data['dependents_application']['student_information'][0][form_key][field] =
                    {
                      'first' => 'Se',
                      'second' => 'e a',
                      'third' => 'dd'
                    }
                end
              end
            end
          end

          # Handles overflow for student networth information section
          #
          # @param form_data [Hash] The form data hash to process
          # @param student_networth [Hash] The student networth data to check for overflow
          # @return [void]
          def handle_networth_overflow(form_data, student_networth)
            networth_overflow = check_networth_overflow(student_networth)

            # If any field overflows, move all fields to overflow page and clear originals
            if networth_overflow.values.any?
              form_data['student_networth_information_overflow'] ||= {}

              %w[savings securities real_estate other_assets total_value].each do |field|
                original_value = student_networth[field]
                if networth_overflow[field.to_sym]
                  # Copy original string value to overflow
                  form_data['student_networth_information_overflow'][field] = original_value
                  # Set original field to 'See add'l info' text similar to rest of overflow handling on 686c-674
                  student_information = form_data['dependents_application']['student_information'][0]
                  student_information['student_networth_information'][field] = {
                    'first' => 'S',
                    'second' => 'ee ',
                    'third' => 'add',
                    'last' => "'l"
                  }
                end
              end
            end
          end
        end
      end
    end
  end
end
