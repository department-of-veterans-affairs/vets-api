# frozen_string_literal: true

require 'debts_api/v0/fsr_form'
module DebtsApi
  class V0::VhaFsrForm < V0::FsrForm
    DATE_TIMEZONE = 'Central Time (US & Canada)'
    VHA_TYPE_KEY = 'COPAY'
    VHA_AMOUNT_KEY = 'pHAmtDue'
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
      @is_streamlined = @streamlined_data ? @streamlined_data['value'] : false # cool
      @form_data = build_vha_form
    end

    def persist_form_submission
      metadata = { copays: @copays }.to_json
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
      debt_amounts = @copays.nil? ? [] : @copays.pluck(VHA_AMOUNT_KEY)
      {
        'combined' => @is_combined,
        'debt_amounts' => debt_amounts,
        'debt_type' => VHA_TYPE_KEY,
        'flags' => enabled_flags,
        'streamlined' => @streamlined_data,
        'zipcode' => @form_data.dig('personalData', 'address', 'zipOrPostalCode') || '???'
      }
    end

    def build_vha_form
      facility_form = @original_data.deep_dup
      facility_form['facilityNum'] = @facility_num
      facility_form['personalIdentification']['fileNumber'] = @user.ssn
      add_compromise_amounts(facility_form, @copays)
      aggregate_fsr_reasons(facility_form, @copays)
      facility_form.delete(DEBTS_KEY)
      facility_form = remove_form_delimiters(facility_form)
      combined_adjustments(facility_form)
      streamline_adjustments(facility_form)
      station_adjustments(facility_form)
      facility_form
    end

    def set_certification_date(form)
      date = Time.now.in_time_zone(self.class::DATE_TIMEZONE)
      date_formatted = date.strftime('%I:%M%p UTC%z %m/%d/%Y')

      form['applicantCertifications']['veteranDateSigned'] = date_formatted if form['applicantCertifications']
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

    def station_adjustments(form)
      stations = []
      @copays.each do |copay|
        stations << 'vista' if copay['pHDfnNumber'].to_i.positive?
        if copay['pHCernerPatientId'].instance_of?(String) && copay['pHCernerPatientId'].strip.length.positive?
          stations << 'cerner'
        end
      end
      stations.uniq!
      form['station_type'] = stations.include?('cerner') && stations.include?('vista') ? 'both' : stations[0]
    end

    def combined_adjustments(form)
      if @is_combined
        comments = form['additionalData']['additionalComments']
        form['additionalData']['additionalComments'] = "Combined FSR. #{comments}"
      end
    end

    def streamline_adjustments(form)
      if @streamlined_data
        form['personalIdentification']['fsrReason'] = 'Automatically Approved, Waiver' if @is_streamlined
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
