# frozen_string_literal: true
module PdfFill
  module Forms
    module VA21P527EZ
      module_function

      ITERATOR = PdfFill::HashConverter::ITERATOR
      KEY = {
        'vaFileNumber' => 'F[0].Page_5[0].VAfilenumber[0]',
        'genderMale' => 'F[0].Page_5[0].Male[0]',
        'genderFemale' => 'F[0].Page_5[0].Female[0]',
        'hasFileNumber' => 'F[0].Page_5[0].YesFiled[0]',
        'noFileNumber' => 'F[0].Page_5[0].NoFiled[0]',
        'nightPhone' => 'F[0].Page_5[0].Eveningphonenumber[0]',
        'nightPhoneAreaCode' => 'F[0].Page_5[0].Eveningareacode[0]',
        'dayPhone' => 'F[0].Page_5[0].Daytimephonenumber[0]',
        'dayPhoneAreaCode' => 'F[0].Page_5[0].Daytimeareacode[0]',
        'vaHospitalTreatmentNames' => "F[0].Page_5[0].Nameandlocationofvamedicalcenter[#{ITERATOR}]",
        'email' => 'F[0].Page_5[0].Preferredemailaddress[0]',
        'altEmail' => 'F[0].Page_5[0].Alternateemailaddress[0]',
        'disabilityNames' => "F[0].Page_5[0].Disability[#{ITERATOR}]",
        'disabilities' => {
          'disabilityStartDate' => "F[0].Page_5[0].DateDisabilityBegan[#{ITERATOR}]"
        },
        'vaHospitalTreatmentDates' => "F[0].Page_5[0].DateofTreatment[#{ITERATOR}]",
        'veteranFullName' => 'F[0].Page_5[0].Veteransname[0]'
      }.freeze

      def expand_va_file_number(va_file_number)
        has_file_number = va_file_number.present?

        {
          'hasFileNumber' => has_file_number,
          'noFileNumber' => !has_file_number
        }
      end

      def split_phone(phone)
        return [nil, nil] if phone.blank?

        [phone[0..2], phone[3..-1]]
      end

      def expand_gender(gender)
        return {} if gender.blank?

        {
          'genderMale' => gender == 'M',
          'genderFemale' => gender == 'F'
        }
      end

      def combine_va_hospital_names(va_hospital_treatments)
        combined = []

        va_hospital_treatments.each do |va_hospital_treatment|
          combined << combine_hash(va_hospital_treatment, %w(name location), ', ')
        end

        combined
      end

      def get_disability_names(disabilities)
        return if disabilities.blank?

        disability_names = Array.new(2, nil)

        disability_names[0] = disabilities[1].try(:[], 'name')
        disability_names[1] = disabilities[0]['name']

        disabilities.map! do |disability|
          disability.except('name')
        end

        disability_names
      end

      def rearrange_hospital_dates(combined_dates)
        # order of boxes in the pdf: 3, 2, 4, 0, 1, 5
        rearranged = Array.new(6, nil)

        [3, 2, 4, 0, 1, 5].each_with_index do |rearranged_i, i|
          rearranged[rearranged_i] = combined_dates[i]
        end

        rearranged
      end

      def combine_va_hospital_dates(va_hospital_treatments)
        combined = []

        va_hospital_treatments.each do |va_hospital_treatment|
          original_dates = va_hospital_treatment['dates']
          dates = Array.new(3, nil)

          dates.each_with_index do |date, i|
            dates[i] = original_dates[i]
          end if original_dates.present?

          combined += dates
        end

        combined
      end

      def combine_hash(hash, keys, separator = ' ')
        return if hash.blank?

        combined = []

        keys.each do |key|
          combined << hash[key]
        end

        combined.compact.join(separator)
      end

      def combine_full_name(full_name)
        combine_hash(full_name, %w(first middle last suffix))
      end

      def merge_fields(form_data)
        form_data_merged = form_data.deep_dup

        form_data_merged['veteranFullName'] = combine_full_name(form_data_merged['veteranFullName'])

        %w(gender vaFileNumber).each do |attr|
          form_data_merged.merge!(public_send("expand_#{attr.underscore}", form_data_merged[attr]))
        end

        %w(nightPhone dayPhone).each do |attr|
          phone_arr = split_phone(form_data_merged[attr])
          form_data_merged["#{attr}AreaCode"] = phone_arr[0]
          form_data_merged[attr] = phone_arr[1]
        end

        form_data_merged['vaHospitalTreatments'].tap do |va_hospital_treatments|
          form_data_merged['vaHospitalTreatmentNames'] = combine_va_hospital_names(va_hospital_treatments)
          form_data_merged['vaHospitalTreatmentDates'] = rearrange_hospital_dates(
            combine_va_hospital_dates(va_hospital_treatments)
          )
        end
        form_data_merged.delete('vaHospitalTreatments')

        form_data_merged['disabilityNames'] = get_disability_names(form_data_merged['disabilities'])

        form_data_merged
      end
    end
  end
end
