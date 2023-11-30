# frozen_string_literal: true

module DebtsApi
  class V0::FsrForm
    class FSRInvalidRequest < StandardError; end

    DEBTS_KEY = 'selectedDebtsAndCopays'
    DEDUCTION_CODES = {
      '30' => 'Disability compensation and pension debt',
      '41' => 'Chapter 34 education debt',
      '44' => 'Chapter 35 education debt',
      '71' => 'Post-9/11 GI Bill debt for books and supplies',
      '72' => 'Post-9/11 GI Bill debt for housing',
      '74' => 'Post-9/11 GI Bill debt for tuition',
      '75' => 'Post-9/11 GI Bill debt for tuition (school liable)'
    }.freeze

    def add_compromise_amounts(form, debts)
      form['additionalData']['additionalComments'] =
        "#{form['additionalData']['additionalComments']} #{get_compromise_amount_text(debts)}"
    end

    def get_compromise_amount_text(debts)
      debts.map do |debt|
        if debt['resolutionOption'] == 'compromise'
          "#{DEDUCTION_CODES[debt['deductionCode']]} compromise amount: $#{debt['resolutionComment']}"
        end
      end.join(', ')
    end

    def aggregate_fsr_reasons(form, debts)
      return if debts.blank?

      form['personalIdentification']['fsrReason'] = debts.pluck('resolutionOption').uniq.join(', ').delete_prefix(', ')
    end
  end
end
