module PdfFill
  module Forms
    # TODO bring back workflow require statements
    class VA21P530 < FormBase
      KEY = {
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[36].VeteransFirstName[0]',
            limit: 12,
            question: "1. DECEASED VETERAN'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[36].VeteransMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[36].VeteransLastName[0]',
            limit: 18,
            question: "1. DECEASED VETERAN'S LAST NAME"
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        }
      }

      def split_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        return if ssn.blank?

        @form_data['veteranSocialSecurityNumber'] = {
          'first' => ssn[0..2],
          'second' => ssn[3..4],
          'third' => ssn[5..8]
        }
      end

      def extract_middle_i
        full_name = @form_data['veteranFullName']
        return if full_name.blank?

        middle_name = full_name['middle']
        return if middle_name.blank?
        full_name['middleInitial'] = middle_name[0]

        @form_data['veteranFullName']
      end

      def merge_fields
        extract_middle_i
        split_ssn

        @form_data
      end
    end
  end
end
