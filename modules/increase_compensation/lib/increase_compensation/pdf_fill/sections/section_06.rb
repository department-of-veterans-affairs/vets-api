# frozen_string_literal: true

require 'increase_compensation/pdf_fill/section'

module IncreaseCompensation
  module PdfFill
    # Section VI: AUTHORIZATION, CERTIFICATION, AND SIGNATURE
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
          'signature' => {
            limit: 38,
            key: 'form1[0].#subform[4].Signature[0]'
          },
          'address1' => { key: 'form1[0].#subform[4].ADDRESS_OF_WITNESS[0]' },
          'address2' => { key: 'form1[0].#subform[4].ADDRESS_OF_WITNESS[1]' }
        },
        'witnessSignature2' => {
          'signature' => {
            limit: 38,
            key: 'form1[0].#subform[4].Signature[1]'
          },
          'address1' => { key: 'form1[0].#subform[4].ADDRESS_OF_WITNESS[2]' },
          'address2' => { key: 'form1[0].#subform[4].ADDRESS_OF_WITNESS[3]' }
        }
      }.freeze
      def expand(form_data = {})
        form_data['signatureDate'] = split_date(form_data['signatureDate'])
        if form_data['witnessSignature1'].present? && form_data['witnessSignature1']['address'].length > 1
          form_data['witnessSignature1'].merge!(
            two_line_overflow(form_data['witnessSignature1']['address'], 'address', 17)
          )
        end
        if form_data['witnessSignature2'].present? && form_data['witnessSignature2']['address'].length > 1
          form_data['witnessSignature2'].merge!(
            two_line_overflow(form_data['witnessSignature2']['address'], 'address', 17)
          )
        end
      end
    end
  end
end
