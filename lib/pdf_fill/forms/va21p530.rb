module PdfFill
  module Forms
    class VA21P530 < FormBase
      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[36].VeteransFirstName[0]',
            limit: 12,
            question: "1. DECEASED VETERAN'S FIRST NAME"
          }
        }
      }

      def extract_middle_i
        full_name = @form_data['veteranFullName']
        return if full_name.blank?

        middle_name = full_name['middle']
        return if middle_name.blank?
        full_name['middleInitial'] = middle_name[0]

        @form_data['veteranFullName']
      end

      def merge_fields
        @form_data
      end
    end
  end
end
