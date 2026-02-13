# frozen_string_literal: true

require 'pdf_fill/forms/formatters/base'

module PdfFill
  module Forms
    module Formatters
      ##
      # Shared formatter for VA Form 686c-674-V2 (Add/Remove Dependent)
      #
      # Provides common formatting methods for both the lib and module versions
      # of the 686c form to eliminate code duplication.
      #
      class Va686c674v2 < Base
        class << self
          ##
          # Expands cases where dependents have no SSN
          #
          # When a spouse or child has no SSN, replaces the SSN field with "See ad d'l"
          # placeholder text and adds the no-SSN reason to the remarks section.
          #
          # @param form_data [Hash] The complete form data hash
          # @return [void] Modifies form_data in place
          def expand_no_ssn_cases(form_data)
            remarks = []

            process_spouse_no_ssn(form_data, remarks)
            process_children_no_ssn(form_data, remarks)
            add_remarks_to_form(form_data, remarks)
          end

          ##
          # Processes spouse no SSN case and adds to remarks
          # @param form_data [Hash] The complete form data hash
          # @param remarks [Array] Array to append spouse no SSN reason to
          # @return [void]
          def process_spouse_no_ssn(form_data, remarks)
            spouse_info = form_data.dig('dependents_application', 'spouse_information')
            return unless spouse_info&.dig('no_ssn')

            set_placeholder_ssn(spouse_info)

            reason = spouse_info['no_ssn_reason']
            return if reason.blank?

            remarks << "11C. Spouse no SSN reason: #{reason}"
          end

          ##
          # Processes children no SSN cases and adds to remarks
          # @param form_data [Hash] The complete form data hash
          # @param remarks [Array] Array to append children no SSN reasons to
          # @return [void]
          def process_children_no_ssn(form_data, remarks)
            children = form_data.dig('dependents_application', 'children_to_add')
            return unless children

            children.each_with_index do |child, index|
              has_no_ssn = child['no_ssn'] || child['no_ssn_reason'].present?
              next unless has_no_ssn

              set_placeholder_ssn(child)

              reason = child['no_ssn_reason']
              next if reason.blank?

              question_number = calculate_child_question_number(index)
              remarks << "#{question_number}B. Child no SSN reason: #{reason}"
            end
          end

          ##
          # Sets placeholder SSN value to indicate addendum reference
          # @param data_hash [Hash] The hash containing the SSN field
          # @return [void]
          def set_placeholder_ssn(data_hash)
            data_hash['ssn'] = {
              'first' => 'See',
              'second' => 'ad',
              'third' => "d'l "
            }
          end

          ##
          # Calculates the question number for child SSN based on index so that it matches the pdf
          # First 4 children question numbers: 16, 17, 18, 19
          # Additional children question numbers: 1, 2, 3, etc.
          # This is because the pdf has specific question numbers for the first 4 children,
          # and then restarts numbering for additional children
          # @param index [Integer] The index of the child
          # @return [Integer] The question number for the child SSN
          def calculate_child_question_number(index)
            index < 4 ? 16 + index : index - 3
          end

          ##
          # Adds remarks to form data, splitting into 35-character lines
          # @param form_data [Hash] The complete form data hash
          # @param remarks [Array] Array of remarks to add to the form
          # @return [void]
          def add_remarks_to_form(form_data, remarks)
            return if remarks.empty?

            combined_text = remarks.join(', ')
            form_data['remarks'] ||= {}

            # Split text into chunks of up to 35 characters and assign to remark lines
            # 35 characters is remark line limit in pdf
            combined_text.scan(/.{1,35}/).each_with_index do |chunk, index|
              form_data['remarks']["remarks_line#{index + 1}"] = chunk
            end
          end
        end
      end
    end
  end
end
