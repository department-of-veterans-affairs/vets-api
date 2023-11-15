# frozen_string_literal: true

module DebtsApi
  class V0::FsrFormBuilder
    class FSRInvalidRequest < StandardError; end

    DATE_TIMEZONE = 'Central Time (US & Canada)'
    DEBTS_KEY = 'selectedDebtsAndCopays'
    VHA_TYPE_KEY = 'COPAY'
    VBA_TYPE_KEY = 'DEBT'
    STREAMLINED_KEY = 'streamlined'
    DEDUCTION_CODES = {
      '30' => 'Disability compensation and pension debt',
      '41' => 'Chapter 34 education debt',
      '44' => 'Chapter 35 education debt',
      '71' => 'Post-9/11 GI Bill debt for books and supplies',
      '72' => 'Post-9/11 GI Bill debt for housing',
      '74' => 'Post-9/11 GI Bill debt for tuition',
      '75' => 'Post-9/11 GI Bill debt for tuition (school liable)'
    }.freeze

    attr_reader :original_form, :sanitized_form,
                :all_debts, :vba_debts, :vha_copays, :grouped_vha_copays, :user_form,
                :is_combined, :streamlined_data, :is_streamlined,
                :vba_form, :vha_forms

    def initialize(form, file_number, user = nil)
      @user = user
      @file_number = file_number
      @original_form = form
      @streamlined_data = form[STREAMLINED_KEY].deep_dup
      @is_streamlined = @streamlined_data ? @streamlined_data['value'] : false

      @sanitized_form = sanitize(form.deep_dup)
      validate_form_schema(@sanitized_form)

      @all_debts = get_debts
      @vba_debts = get_vba_debts
      @vha_copays = get_vha_copays
      @grouped_vha_copays = grouped_copays
      @is_combined = (!vba_debts&.empty? && !vha_copays&.empty?)

      @user_form = build_user_form
      @vba_form = build_vba_form
      @vha_forms = build_vha_forms # shaped like: [ {form: facility_form, copays: copays}, ... ]
    end

    def validate_form_schema(form)
      schema_path = Rails.root.join('lib', 'debt_management_center', 'schemas', 'fsr.json').to_s
      errors = JSON::Validator.fully_validate(schema_path, form)

      raise FSRInvalidRequest if errors.any?
    end

    def sanitize(form)
      add_personal_identification(form)
      form.reject! { |k, _v| k == 'streamlined' }
      form
    end

    def build_user_form
      form = sanitize(@original_form.deep_dup)
      aggregate_fsr_reasons(form, @all_debts)
      form
    end

    def add_personal_identification(form)
      form = camelize(form)
      raise_client_error unless form.key?('personalIdentification')
      form['personalIdentification']['fileNumber'] = @file_number
      set_certification_date(form)
      form
    end

    def camelize(hash)
      hash.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
    end

    def raise_client_error
      raise Common::Client::Errors::ClientError.new('malformed request', 400)
    end

    def set_certification_date(form)
      date = Time.now.in_time_zone(self.class::DATE_TIMEZONE).to_date
      date_formatted = date.strftime('%m/%d/%Y')

      form['applicantCertifications']['veteranDateSigned'] = date_formatted if form['applicantCertifications']
    end

    def get_debts
      @sanitized_form.deep_dup[DEBTS_KEY]
    end

    def get_vba_debts
      @all_debts&.filter { |debt| debt['debtType'] == VBA_TYPE_KEY }
    end

    def get_vha_copays
      copays = @all_debts&.filter { |debt| debt['debtType'] == VHA_TYPE_KEY }
      copays.nil? ? [] : copays
    end

    def grouped_copays
      if @vha_copays
        @vha_copays.group_by { |copay| copay['station']['facilitYNum'] }
      else
        {}
      end
    end

    def build_vha_forms
      vha_forms = []
      @grouped_vha_copays.each do |facility_num, copays|
        facility_form = @sanitized_form.deep_dup
        facility_form['facilityNum'] = facility_num
        facility_form['personalIdentification']['fileNumber'] = @user.ssn
        add_compromise_amounts(facility_form, copays)
        facility_form.delete(DEBTS_KEY)
        facility_form = remove_form_delimiters(facility_form)
        combined_adjustments(facility_form)
        streamline_adjustments(facility_form)
        vha_forms << { form: facility_form, copays: }
      end
      vha_forms
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

    def build_vba_form
      form = @sanitized_form.deep_dup
      form.delete(DEBTS_KEY)
      if @vba_debts.present?
        add_compromise_amounts(form, @vba_debts)
        aggregate_fsr_reasons(form, @vba_debts)
        form
      else
        # Edge case for old flow (pre-combined) that didn't include this field
        return form if all_debts && all_debts.empty?

        nil
      end
    end

    def aggregate_fsr_reasons(form, debts)
      return if debts.blank?

      form['personalIdentification']['fsrReason'] = debts.pluck('resolutionOption').uniq.join(', ').delete_prefix(', ')
    end

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

    def remove_form_delimiters(form)
      form.deep_transform_values do |val|
        if val.is_a?(String)
          val.gsub(/[\^|\n]/, '')
        else
          val
        end
      end
    end
  end
end
