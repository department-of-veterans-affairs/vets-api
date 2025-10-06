# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section VI: Mileage
    class Section6 < Section
      # Section configuration hash
      KEY = {
        'signature' => {
          key: 'form1[0].#subform[4].Signature[0]'
        },
        'signatureDate' => {
          'month' => {
            key: 'form1[0].#subform[4].DATESOFEMPLOYMENT5_FROM_MONTH[1]'
          },
          'day' => {
            key: 'form1[0].#subform[4].DATESOFEMPLOYMENT5_FROM_DAY[1]'
          },
          'year' => {
            key: 'form1[0].#subform[4].DATESOFEMPLOYMENT5_FROM_YEAR[1]'
          }
        },
        'witnessSignature1' => {
          'signature' => { key: 'form1[0].#subform[4].Signature[0]' },
          'address' => { key: 'form1[0].#subform[4].ADDRESS_OF_WITNESS[0]' },
          'address2' => { key: 'form1[0].#subform[4].ADDRESS_OF_WITNESS[1]' }
        },
        'witnessSignature2' => {
          'signature' => { key: 'form1[0].#subform[4].Signature[1]' },
          'address' => { key: 'form1[0].#subform[4].ADDRESS_OF_WITNESS[2]' },
          'address2' => { key: 'form1[0].#subform[4].ADDRESS_OF_WITNESS[3]' }
        }
      }.freeze
      def expand(form_data = {})
      end
    end
  end
end
