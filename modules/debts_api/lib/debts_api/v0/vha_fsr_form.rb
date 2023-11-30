# frozen_string_literal: true

require 'debts_api/v0/fsr_form'
module DebtsApi
  class V0::VhaFsrForm < V0::FsrForm
    VHA_TYPE_KEY = 'COPAY'
    DEBTS_KEY = 'selectedDebtsAndCopays'

    attr_reader :form_data, :copays, :is_combined, :is_streamlined, :streamlined_data

    def initialize(params)
      super()
      @original_data = params[:form]
      @user = params[:user]
      @facility_num = params[:facility_num]
      @copays = params[:copays]
      @is_combined = params[:combined]
      @streamlined_data = params[:streamlined_data]
      @is_streamlined = @streamlined_data ? @streamlined_data['value'] : false
      @form_data = build_vha_form
    end

    def build_vha_form
      facility_form = @original_data.deep_dup
      facility_form['facilityNum'] = @facility_num
      facility_form['personalIdentification']['fileNumber'] = @user.ssn
      add_compromise_amounts(facility_form, @copays)
      facility_form.delete(DEBTS_KEY)
      facility_form = remove_form_delimiters(facility_form)
      combined_adjustments(facility_form)
      streamline_adjustments(facility_form)
      facility_form
    end

    def remove_form_delimiters(form)
      form.deep_transform_values do |val|
        if val.is_a?(String)
          val.gsub(/[\^|\n]/, '')
        else
          val
        end
      end
    end

    def combined_adjustments(form)
      if @is_combined
        comments = form['additionalData']['additionalComments']
        form['additionalData']['additionalComments'] = "Combined FSR. #{comments}"
      end
    end

    def streamline_adjustments(form)
      if @streamlined_data
        if @is_streamlined
          reasons = form.dig('personalIdentification', 'fsrReason')
          reasons_array = reasons.nil? ? [] : reasons.split(',').map(&:strip)
          reasons = reasons_array.push('Automatically Approved').uniq.join(', ')
          form['personalIdentification']['fsrReason'] = reasons
        end
        form['streamlined'] = @is_streamlined
      end
    end

    def self.forms_from_submission_obj(params)
      user = params[:user]
      all_debts = params[:all_debts]
      return [] if all_debts.nil?

      sanitized_form = params[:sanitized_form]
      copays = get_vha_copays(all_debts)
      grouped_copays = get_grouped_copays(copays)
      is_combined = copays.length < all_debts.length

      forms = []
      grouped_copays.each do |facility_num, facility_copays|
        facility_params = {
          user:,
          form: sanitized_form,
          copays: facility_copays,
          facility_num:,
          combined: is_combined,
          streamlined_data: params[:streamlined_data]
        }
        forms << DebtsApi::V0::VhaFsrForm.new(facility_params)
      end
      forms
    end

    def self.get_vha_copays(all_debts)
      copays = all_debts&.filter { |debt| debt['debtType'] == VHA_TYPE_KEY }
      copays.nil? ? [] : copays
    end

    def self.get_grouped_copays(copays)
      if copays
        copays.group_by { |copay| copay['station']['facilitYNum'] }
      else
        {}
      end
    end
  end
end
