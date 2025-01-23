# frozen_string_literal: true

require 'debts_api/v0/vha_fsr_form'
require 'debts_api/v0/vba_fsr_form'
require 'debts_api/v0/user_fsr_form'

module DebtsApi
  class V0::FsrFormBuilder
    class FSRInvalidRequest < StandardError; end

    DATE_TIMEZONE = 'Central Time (US & Canada)'
    DEBTS_KEY = 'selectedDebtsAndCopays'
    STREAMLINED_KEY = 'streamlined'

    attr_reader :original_form, :sanitized_form,
                :all_debts, :vba_debts, :vha_copays, :user_form,
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
      @user_form = build_user_form
      @vba_form = build_vba_form
      @vha_forms = build_vha_forms
      @is_combined = @vha_forms.present? && @vha_forms.first.is_combined
    end

    def validate_form_schema(form)
      schema_path = Rails.root.join('lib', 'debt_management_center', 'schemas', 'fsr.json').to_s
      errors = JSON::Validator.fully_validate(schema_path, form)

      if errors.any?
        Rails.logger.error("DebtsApi::V0::FsrFormBuilder validation failed: #{errors}")
        raise FSRInvalidRequest
      end
    end

    def sanitize(form)
      add_personal_identification(form)
      form.reject! { |k, _v| k == 'streamlined' }
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

    def build_user_form
      params = {
        form: @sanitized_form,
        user: @user,
        all_debts: @all_debts
      }
      form = DebtsApi::V0::UserFsrForm.new(params)
      form.form_data.nil? ? nil : form
    end

    def build_vha_forms
      params = {
        user: @user,
        original_form: @original_form,
        sanitized_form: @sanitized_form,
        all_debts: @all_debts,
        streamlined_data: @streamlined_data
      }
      DebtsApi::V0::VhaFsrForm.forms_from_submission_obj(params)
    end

    def build_vba_form
      params = {
        form: @sanitized_form,
        user: @user,
        all_debts: @all_debts
      }
      form = DebtsApi::V0::VbaFsrForm.new(params)
      form.form_data.nil? ? nil : form
    end

    def destroy_related_form
      InProgressForm.form_for_user('5655', @user)&.destroy!
    end
  end
end
