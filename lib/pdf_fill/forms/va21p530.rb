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

      def merge_fields
        @form_data
      end
    end
  end
end
