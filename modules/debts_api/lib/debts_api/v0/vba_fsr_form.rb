# frozen_string_literal: true

require 'debts_api/v0/fsr_form'
module DebtsApi
  class V0::VbaFsrForm < V0::FsrForm
    VBA_TYPE_KEY = 'DEBT'
    DEBTS_KEY = 'selectedDebtsAndCopays'

    attr_reader :form_data, :debts

    def initialize(params)
      super()
      @original_data = params[:form]
      @user = params[:user]
      @all_debts = params[:all_debts]
      @debts = get_vba_debts
      @form_data = build_vba_form
    end

    def get_vba_debts
      @all_debts&.filter { |debt| debt['debtType'] == VBA_TYPE_KEY }
    end

    def build_vba_form
      form = @original_data.deep_dup
      form.delete(DEBTS_KEY)
      if @debts.present?
        add_compromise_amounts(form, @debts)
        aggregate_fsr_reasons(form, @debts)
        form
      else
        # Edge case for old flow (pre-combined) that didn't include this field
        return form if @all_debts && @all_debts.empty?

        nil
      end
    end
  end
end
