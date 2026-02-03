# frozen_string_literal: true

require 'pdf_fill/forms/formatters/base'

module PdfFill
  module Forms
    module Formatters
      class Va21674v2 < Base
        class << self
          INCOME_CHAR_LIMIT = 8
          NETWORTH_CHAR_LIMIT = 10

          def expand_phone_number(phone_number)
            phone_number = phone_number.to_s.delete('^0-9')
            {
              'phone_area_code' => phone_number[0..2] || '',
              'phone_first_three_numbers' => phone_number[3..5] || '',
              'phone_last_four_numbers' => phone_number[6..9] || ''
            }
          end

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
          def format_checkboxes(dependents_application)
            students_information = dependents_application['student_information']
            if students_information.present?
              students_information.each do |student_information|
                was_married = student_information['was_married']
                student_information['was_married'] = {
                  'was_married_yes' => select_checkbox(was_married),
                  'was_married_no' => select_checkbox(!was_married)
                }

                is_paid = student_information['tuition_is_paid_by_gov_agency']
                student_information['tuition_is_paid_by_gov_agency'] = {
                  'is_paid_yes' => select_checkbox(is_paid),
                  'is_paid_no' => select_checkbox(!is_paid)
                }

                is_full_time = student_information['school_information']['student_is_enrolled_full_time']
                student_information['school_information']['student_is_enrolled_full_time'] = {
                  'full_time_yes' => select_checkbox(is_full_time),
                  'full_time_no' => select_checkbox(!is_full_time)
                }

                did_attend = student_information['school_information']['student_did_attend_school_last_term']
                student_information['school_information']['student_did_attend_school_last_term'] = {
                  'did_attend_yes' => select_checkbox(did_attend),
                  'did_attend_no' => select_checkbox(!did_attend)
                }

                is_school_accredited = student_information['school_information']['is_school_accredited']
                student_information['school_information']['is_school_accredited'] = {
                  'is_school_accredited_yes' => select_radio_button(is_school_accredited),
                  'is_school_accredited_no' => select_radio_button(!is_school_accredited)
                }
              end
            end
          end
          # rubocop:enable Metrics/MethodLength

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

          # checks the passed in attribute against the limit for the fields passed in.
          def check_for_single_overflow(data, size)
            return false if data.is_a?(Hash) || data.blank?

            data.size > size
          end

          # override from form_helper
          def select_checkbox(value)
            value ? 'On' : nil
          end

          def select_radio_button(value)
            value ? 0 : nil
          end
        end
      end
    end
  end
end
