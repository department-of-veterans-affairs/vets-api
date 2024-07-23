# frozen_string_literal: true

require 'debts_api/v0/fsr_form'
module DebtsApi
  class V0::VbaFsrForm < V0::FsrForm
    VBA_TYPE_KEY = 'DEBT'
    VBA_AMOUNT_KEY = 'currentAr'
    DEBTS_KEY = 'selectedDebtsAndCopays'

    attr_reader :form_data, :debts

    def initialize(params)
      super()
      @original_data = params[:form]
      @user = params[:user]
      @all_debts = params[:all_debts].nil? ? [] : params[:all_debts]
      @debts = get_vba_debts
      @is_combined = @debts.length < @all_debts.length && @all_debts.length.positive?
      @form_data = build_vba_form
    end

    def persist_form_submission
      metadata = { debts: @debts }.to_json
      public_metadata = build_public_metadata
      ipf = in_progress_form(@user.uuid)
      ipf_data = ipf&.form_data

      DebtsApi::V0::Form5655Submission.create(
        form_json: @form_data.to_json,
        metadata:,
        ipf_data:,
        user_uuid: @user.uuid,
        user_account: @user.user_account,
        public_metadata:,
        state: 1
      )
    end

    def build_public_metadata
      enabled_flags = enabled_feature_flags(@user)
      debt_amounts = @debts.pluck(VBA_AMOUNT_KEY)
      {
        'combined' => @is_combined,
        'debt_amounts' => debt_amounts,
        'debt_type' => VBA_TYPE_KEY,
        'flags' => enabled_flags,
        'streamlined' => nil,
        'zipcode' => @form_data.dig('personalData', 'address', 'zipOrPostalCode') || '???'
      }
    end

    def get_vba_debts
      debts = @all_debts&.filter { |debt| debt['debtType'] == VBA_TYPE_KEY }
      debts.nil? ? [] : debts
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
