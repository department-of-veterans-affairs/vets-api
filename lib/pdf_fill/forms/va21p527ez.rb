# frozen_string_literal: true
module PdfFill
  module Forms
    module VA21P527EZ
      module_function

      KEY = {
        'vaFileNumber' => 'F[0].Page_5[0].VAfilenumber[0]',
        'genderMale' => 'F[0].Page_5[0].Male[0]',
        'genderFemale' => 'F[0].Page_5[0].Female[0]',
        'veteranFullName' => 'F[0].Page_5[0].Veteransname[0]'
      }.freeze

      def expand_va_file_number(va_file_number)
        has_file_number = va_file_number.present?

        {
          'has_file_number' => has_file_number,
          'no_file_number' => !has_file_number
        }
      end

      def expand_gender(gender)
        return {} if gender.blank?

        {
          'genderMale' => gender == 'M',
          'genderFemale' => gender == 'F'
        }
      end

      def combine_full_name(full_name)
        return if full_name.blank?
        combined_name = []

        %w(first middle last suffix).each do |key|
          combined_name << full_name[key]
        end

        combined_name.compact.join(' ')
      end

      def merge_fields(form_data)
        form_data_merged = form_data.deep_dup

        form_data_merged['veteranFullName'] = combine_full_name(form_data_merged['veteranFullName'])

        %w(gender vaFileNumber).each do |attr|
          form_data_merged.merge!(public_send("expand_#{attr.underscore}", form_data_merged[attr]))
        end

        form_data_merged
      end
    end
  end
end
