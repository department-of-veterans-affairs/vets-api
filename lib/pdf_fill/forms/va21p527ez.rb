# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'string_helpers'

module PdfFill
  module Forms
    class Va21p527ez < FormBase
      KEY = {
        # the key is used to translate your json schema validated form into a hash that can be passed
        # to the pdf-forms library which will write out text onto the pdf
        # the keys in this hash should match the keys in the hash that is submitted from the frontend
        'veteranFullName' => {
          'first' => {
            # the key here is the name of the field in the pdf. you can use acrobat pro or an online
            # editor like https://www.pdfescape.com to find out what the field names are.
            key: 'form1[0].#subform[48].VeteransFirstName[0]',
            # character limit for this field. if a value goes over the character limit extra pages
            # are attached to the end of the pdf that look like this
            # https://github.com/department-of-veterans-affairs/vets-api/blob/master/spec/fixtures/pdf_fill/21P-530/overflow_extras.pdf
            # the field itself will have the text "See add'l info page"
            limit: 12,
            # the question number and question suffix are used to order the questions on the additional
            # information page. the question text is written on the additional information page.
            question_num: 1,
            question_suffix: 'A',
            question_text: "VETERAN'S FIRST NAME"
          },
          'middle' => {
            key: 'form1[0].#subform[48].VeteransMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[48].VeteransLastName[0]',
            limit: 18,
            question_num: 1,
            question_suffix: 'A',
            question_text: "VETERAN'S LAST NAME"
          }
        }
      }.freeze

      def merge_fields(_options = {})
        # your class must include this method, it can be used to make changes to the form
        # before final processing
        @form_data['veteranFullName']['first'] = @form_data['veteranFullName']['first']&.titleize
        @form_data['veteranFullName']['middle'] = @form_data['veteranFullName']['middle']&.titleize
        @form_data['veteranFullName']['last'] = @form_data['veteranFullName']['last']&.titleize
        @form_data
      end
    end
  end
end
