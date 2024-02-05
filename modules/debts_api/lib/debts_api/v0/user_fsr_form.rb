# frozen_string_literal: true

require 'debts_api/v0/fsr_form'
module DebtsApi
  class V0::UserFsrForm < V0::FsrForm
    attr_reader :form_data, :all_debts

    def initialize(params)
      super()
      @original_data = params[:form]
      @user = params[:user]
      @all_debts = params[:all_debts]
      @form_data = build_user_form
    end

    def build_user_form
      form = @original_data.deep_dup
      aggregate_fsr_reasons(form, @all_debts)
      form
    end
  end
end
