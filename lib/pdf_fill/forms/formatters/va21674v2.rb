# frozen_string_literal: true

require 'pdf_fill/forms/formatters/base'

module PdfFill
  module Forms
    module Formatters
      class Va21674v2 < Base
        class << self
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

          def select_checkbox(value)
            value ? 'On' : nil
          end

          def select_radio_button(value)
            value ? 0 : nil
          end

          def split_earnings(parent_object)
            return if parent_object.blank?

            keys_to_process = %w[
              earnings_from_all_employment annual_social_security_payments
              other_annuities_income all_other_income
            ]
            keys_to_process.each do |key|
              value = parent_object[key]
              next if value.blank?

              cleaned_value = value.to_s.gsub(/[^0-9]/, '').to_i
              parent_object[key] = {
                'first' => ((cleaned_value % 1_000_000) / 1000).to_s.rjust(2, '0')[-3..] || '00',
                'second' => (cleaned_value % 1000).to_s.rjust(3, '0') || '000',
                'third' => '00'
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

              cleaned_value = value.to_s.gsub(/[^0-9]/, '').to_i

              parent_object[key] = {
                'first' => (cleaned_value / 1_000_000).to_s[-2..],
                'second' => ((cleaned_value % 1_000_000) / 1000).to_s.rjust(3, '0')[-3..],
                'third' => (cleaned_value % 1000).to_s.rjust(3, '0'),
                'last' => '00'
              }
            end
            parent_object
          end
        end
      end
    end
  end
end
