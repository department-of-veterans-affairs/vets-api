# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'

module PdfFill
  module Forms
    class Va21p527ezare < FormBase
      include FormHelper
      
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
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[48].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[48].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[48].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        },
        'veteranDateOfBirth' => {
          'month' => {
            key: 'form1[0].#subform[48].DOBmonth[0]'
          },
          'day' => {
            key: 'form1[0].#subform[48].DOBday[0]'
          },
          'year' => {
            key: 'form1[0].#subform[48].DOByear[0]'
          }
        },
        'vaPreviouslyFiled' => {
          key: 'form1[0].#subform[48].RadioButtonList[0]'
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[48].VAFileNumber[0]'
        },
      }.freeze

      def merge_section_1_fields
        @form_data['veteranFullName']['first'] = @form_data['veteranFullName']['first']&.titleize
        @form_data['veteranFullName']['middle'] = @form_data['veteranFullName']['middle']&.titleize
        @form_data['veteranFullName']['last'] = @form_data['veteranFullName']['last']&.titleize

        ssn = @form_data['veteranSocialSecurityNumber']
        @form_data["veteranSocialSecurityNumber"] = split_ssn(ssn)

        @form_data['veteranDateOfBirth'] = split_date(@form_data['veteranDateOfBirth'])
        @form_data['vaPreviouslyFiled'] = @form_data['vaFileNumber'].present? ? 1 : 2 # 1 => yes, 2 => no
      end

      def merge_fields(_options = {})
        # your class must include this method, it can be used to make changes to the form
        # before final processing
        merge_section_1_fields

        @form_data
      end
    end
  end
end
