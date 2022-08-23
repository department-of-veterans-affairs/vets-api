# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debt_management_center/financial_status_report_configuration'
require 'debt_management_center/responses/financial_status_report_response'
require 'debt_management_center/models/financial_status_report'
require 'debt_management_center/financial_status_report_downloader'
require 'debt_management_center/workers/va_notify_email_job'
require 'debt_management_center/vbs/request'
require 'json'

module DebtManagementCenter
  ##
  # Service that integrates with the Debt Management Center's Financial Status Report endpoints.
  # Allows users to submit financial status reports, and download copies of completed reports.
  #
  class FinancialStatusReportService < DebtManagementCenter::BaseService
    include SentryLogging

    class FSRNotFoundInRedis < StandardError; end
    class FSRInvalidRequest < StandardError; end

    configuration DebtManagementCenter::FinancialStatusReportConfiguration

    STATSD_KEY_PREFIX = 'api.dmc'
    DATE_TIMEZONE = 'Central Time (US & Canada)'
    CONFIRMATION_TEMPLATE = Settings.vanotify.services.dmc.template_id.fsr_confirmation_email

    ##
    # Submit a financial status report to the Debt Management Center
    #
    # @param form [JSON] JSON serialized form data of a Financial Status Report form (VA-5655)
    # @return [Hash]
    #
    def submit_financial_status_report(form)
      with_monitoring_and_error_handling do
        form = add_personal_identification(form)
        validate_form_schema(form)
        if Flipper.enabled?(:combined_financial_status_report, @user)
          submit_combined_fsr(form)
        else
          submit_vba_fsr(form)
        end
      end
    end

    ##
    # Downloads a copy of a user's filled Financial Status Report (VA-5655)
    #
    # @return [String]
    #
    def get_pdf
      financial_status_report = DebtManagementCenter::FinancialStatusReport.find(@user.uuid)

      raise FSRNotFoundInRedis if financial_status_report.blank?

      downloader = DebtManagementCenter::FinancialStatusReportDownloader.new(financial_status_report)
      downloader.download_pdf
    end

    def submit_combined_fsr(form)
      persist_form_submission(form)
      vba_status = submit_vba_fsr(form) if selected_vba_debts(form['selectedDebtsAndCopays']).present?
      vha_status = submit_vha_fsr(form) if selected_vha_copays(form['selectedDebtsAndCopays']).present?

      { vba_status: vba_status, vha_status: vha_status }.compact
    end

    def submit_vba_fsr(form)
      form.delete('selectedDebtsAndCopays')
      response = perform(:post, 'financial-status-report/formtopdf', form)
      fsr_response = DebtManagementCenter::FinancialStatusReportResponse.new(response.body)

      send_confirmation_email if response.success?

      update_filenet_id(fsr_response)
      { status: fsr_response.status }
    end

    def submit_vha_fsr(form)
      vha_forms = parse_vha_form(form)
      request = DebtManagementCenter::VBS::Request.build
      vbs_responses = []
      vha_forms.each do |vha_form|
        response = request.post("#{vbs_settings.base_path}/UploadFSRJsonDocument", { jsonDocument: vha_form.to_json })
        vbs_responses << response
      end

      send_confirmation_email if vbs_responses.all?(&:success?)

      { status: vbs_responses.collect(&:status) }
    end

    private

    def raise_client_error
      raise Common::Client::Errors::ClientError.new('malformed request', 400)
    end

    def parse_vha_form(form)
      facility_forms = []
      facility_copays = selected_vha_copays(form['selectedDebtsAndCopays']).group_by do |copay|
        copay['station']['facilitYNum']
      end
      facility_copays.each do |facility_num, copays|
        fsr_reason = copays.map do |c|
          c['resolutionOption']
        end.uniq.join(', ') + " - Facility #{facility_num}}"
        facility_form = form.deep_dup
        facility_form['personalIdentification']['fsrReason'] = fsr_reason
        facility_form['facilityNum'] = facility_num
        facility_form.delete('selectedDebtsAndCopays')
        facility_forms << remove_form_delimiters(facility_form)
      end

      facility_forms
    end

    def persist_form_submission(form)
      metadata = {
        debts: selected_vba_debts(form['selectedDebtsAndCopays']),
        copays: selected_vha_copays(form['selectedDebtsAndCopays'])
      }.to_json
      form_json = form.deep_dup

      form_json.delete('selectedDebtsAndCopays')

      Form5655Submission.create(
        form_json: form_json.to_json,
        metadata: metadata,
        user_uuid: @user.uuid
      )
    end

    def selected_vba_debts(debts)
      debts&.filter { |debt| debt['debtType'] == 'DEBT' }
    end

    def selected_vha_copays(debts)
      debts&.filter { |debt| debt['debtType'] == 'COPAY' }
    end

    def update_filenet_id(response)
      fsr_params = { REDIS_CONFIG[:financial_status_report][:namespace] => @user.uuid }
      fsr = DebtManagementCenter::FinancialStatusReport.new(fsr_params)
      fsr.update(filenet_id: response.filenet_id, uuid: @user.uuid)

      begin
        # Calling #update! will not raise a proper AR validation error
        # Instead use #validate! to raise an ActiveModel::ValidationError error which contains a more detailed message
        fsr.validate!
      rescue ActiveModel::ValidationError => e
        log_exception_to_sentry(e, { fsr_attributes: fsr.attributes, fsr_response: response.to_h })
      end
    end

    def camelize(hash)
      hash.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
    end

    def add_personal_identification(form)
      form = camelize(form)
      raise_client_error unless form.key?('personalIdentification')
      form['personalIdentification']['fileNumber'] = @file_number
      set_certification_date(form)
      form
    end

    def validate_form_schema(form)
      schema_path = Rails.root.join('lib', 'debt_management_center', 'schemas', 'fsr.json').to_s
      errors = JSON::Validator.fully_validate(schema_path, form)

      raise FSRInvalidRequest if errors.any?
    end

    def set_certification_date(form)
      date            = Time.now.in_time_zone(self.class::DATE_TIMEZONE).to_date
      date_formatted  = date.strftime('%m/%d/%Y')

      form['applicantCertifications']['veteranDateSigned'] = date_formatted if form['applicantCertifications']
    end

    def send_confirmation_email
      return unless Flipper.enabled?(:fsr_confirmation_email)

      email = @user.email&.downcase
      return if email.blank?

      DebtManagementCenter::VANotifyEmailJob.perform_async(email, CONFIRMATION_TEMPLATE, email_personalization_info)
    end

    def email_personalization_info
      { 'name' => @user.first_name, 'time' => '48 hours', 'date' => Time.zone.now.strftime('%m/%d/%Y') }
    end

    def remove_form_delimiters(form)
      JSON.parse(form.to_s.gsub(/[\^|]/, '').gsub('=>', ':'))
    end

    def vbs_settings
      Settings.mcp.vbs_v2
    end
  end
end
