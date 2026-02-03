# frozen_string_literal: true

require_relative '../section'

module Burials
  module PdfFill
    # Section VIII: Signature
    class Section8V2 < Section
      # Section configuration hash
      KEY = {
        'signature' => {
          key: 'form1[0].#subform[83].CLAIMANT_SIGNATURE[0]',
          limit: 45,
          question_num: 32,
          question_label: 'Signature Of Claimant',
          question_text: 'SIGNATURE OF CLAIMANT',
          question_suffix: 'A'
        }
      }.freeze

      ##
      # Expands the form data
      #
      # @param form_data [Hash]
      #
      # @note Modifies `form_data`
      #
      def expand(form_data)
        signature = combine_hash(form_data['claimantFullName'], %w[first last])
        form_data['signature'] = signature
        form_data['signatureDate'] = Time.zone.today.to_s if signature.present?
        expand_checkbox_in_place(form_data, 'processOption')
      end
    end
  end
end
