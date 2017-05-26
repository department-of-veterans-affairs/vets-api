module PdfFill
  module Forms
    module VA21P527EZ
      module_function

      KEY = {
        'vaFileNumber' => 'F[0].Page_5[0].VAfilenumber[0]',
        'veteranFullName' => 'F[0].Page_5[0].Veteransname[0]'
      }

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

        form_data_merged.merge!(expand_gender(form_data_merged['gender']))

        form_data_merged
      end
    end
  end
end
