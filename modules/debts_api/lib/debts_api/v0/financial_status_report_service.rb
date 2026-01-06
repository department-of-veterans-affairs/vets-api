# frozen_string_literal: true

require 'debt_management_center/base_service'
require 'debts_api/v0/financial_status_report_configuration'
require 'debts_api/v0/fsr_form_builder'
require 'debts_api/v0/responses/financial_status_report_response'
require 'debt_management_center/models/financial_status_report'
require 'debts_api/v0/financial_status_report_downloader'
require 'debt_management_center/sidekiq/va_notify_email_job'
require 'debt_management_center/vbs/request'
require 'debt_management_center/sharepoint/request'
require 'debts_api/v0/form5655/send_confirmation_email_job'
require 'pdf_fill/filler'
require 'sidekiq'
require 'sidekiq/attr_package'
require 'json'

module DebtsApi
  ##
  # Service that integrates with the Debt Management Center's Financial Status Report endpoints.
  # Allows users to submit financial status reports, and download copies of completed reports.
  #
  class V0::FinancialStatusReportService < DebtManagementCenter::BaseService
    include Vets::SharedLogging

    class FSRNotFoundInRedis < StandardError; end
    class FSRInvalidRequest < StandardError; end
    class FailedFormToPdfResponse < StandardError; end

    configuration DebtsApi::V0::FinancialStatusReportConfiguration

    STATSD_KEY_PREFIX = 'api.dmc'
    DATE_TIMEZONE = 'Central Time (US & Canada)'
    VBA_CONFIRMATION_TEMPLATE = Settings.vanotify.services.dmc.template_id.fsr_confirmation_email
    VHA_CONFIRMATION_TEMPLATE = Settings.vanotify.services.dmc.template_id.vha_fsr_confirmation_email
    STREAMLINED_CONFIRMATION_TEMPLATE = Settings.vanotify.services.dmc.template_id.fsr_streamlined_confirmation_email
    IN_PROGRESS_TEMPLATE_ID = Settings.vanotify.services.dmc.template_id.fsr_step_1_submission_in_progress_email
    DEDUCTION_CODES = {
      '30' => 'Disability compensation and pension debt',
      '41' => 'Chapter 34 education debt',
      '44' => 'Chapter 35 education debt',
      '71' => 'Post-9/11 GI Bill debt for books and supplies',
      '72' => 'Post-9/11 GI Bill debt for housing',
      '74' => 'Post-9/11 GI Bill debt for tuition',
      '75' => 'Post-9/11 GI Bill debt for tuition (school liable)'
    }.freeze

    ##
    # Submit a financial status report to the Debt Management Center
    #
    # @param form [JSON] JSON serialized form data of a Financial Status Report form (VA-5655)
    # @return [Hash]
    #
    def submit_financial_status_report(form)
      if Flipper.enabled?(:fsr_zero_silent_errors_in_progress_email)
        cache_key = Sidekiq::AttrPackage.create(email: @user.email, first_name: @user.first_name)
        DebtsApi::V0::Form5655::SendConfirmationEmailJob.perform_in(
          5.minutes,
          {
            'submission_type' => 'fsr',
            'cache_key' => cache_key,
            'user_uuid' => @user.uuid,
            'template_id' => IN_PROGRESS_TEMPLATE_ID
          }
        )
      end
      with_monitoring_and_error_handling do
        form_builder = DebtsApi::V0::FsrFormBuilder.new(form, @file_number, @user)
        submit_combined_fsr(form_builder)
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

      downloader = DebtsApi::V0::FinancialStatusReportDownloader.new(financial_status_report)
      downloader.download_pdf
    end

    def submit_combined_fsr(fsr_builder)
      Rails.logger.info('Submitting Combined FSR')
      create_vba_fsr(fsr_builder)
      create_vha_fsr(fsr_builder)
      fsr_builder.destroy_related_form
      user_form = fsr_builder.user_form.form_data

      {
        content: Base64.encode64(
          File.read(
            PdfFill::Filler.fill_ancillary_form(
              user_form,
              SecureRandom.uuid,
              '5655'
            )
          )
        )
      }
    end

    def create_vba_fsr(fsr_builder)
      if fsr_builder.vba_form
        vba_submission = persist_vba_form_submission(fsr_builder)
        vba_submission.submit_to_vba
      end
    end

    def create_vha_fsr(fsr_builder)
      if fsr_builder.vha_forms.present?
        submissions = persist_vha_form_submission(fsr_builder)
        submit_vha_batch_job(submissions)
      end
    end

    def submit_vba_fsr(form)
      Rails.logger.info('5655 Form Submitting to VBA')
      form.delete('streamlined')
      response = measure_latency("#{STATSD_KEY_PREFIX}.fsr.submit.vba.latency") do
        perform(:post, 'financial-status-report/formtopdf', form)
      end

      fsr_response = DebtsApi::V0::FinancialStatusReportResponse.new(response.body)
      raise FailedFormToPdfResponse unless response.success?

      unless Flipper.enabled?(:fsr_zero_silent_errors_in_progress_email)
        send_confirmation_email(VBA_CONFIRMATION_TEMPLATE)
      end

      update_filenet_id(fsr_response)

      { status: fsr_response.status }
    end

    def submit_vha_fsr(form_submission)
      vha_form = form_submission.form
      vha_form['transactionId'] = form_submission.id
      vha_form['timestamp'] = DateTime.now.strftime('%Y%m%dT%H%M%S')
      vbs_request = DebtManagementCenter::VBS::Request.build
      sharepoint_request = DebtManagementCenter::Sharepoint::Request.new
      Rails.logger.info('5655 Form Submitting to VHA', submission_id: form_submission.id)
      sharepoint_request.upload(
        form_contents: vha_form,
        form_submission:,
        station_id: vha_form['facilityNum']
      )
      vha_response = measure_latency("#{STATSD_KEY_PREFIX}.fsr.submit.vha.latency") do
        vbs_request.post("#{vbs_settings.base_path}/UploadFSRJsonDocument",
                         { jsonDocument: vha_form.to_json })
      end

      form_submission.submitted!
      { status: vha_response.status }
    rescue => e
      form_submission.register_failure("FinancialStatusReportService#submit_vha_fsr: #{e.message}")
      raise e
    end

    def submit_to_vbs(form_submission)
      form = add_vha_specific_data(form_submission)

      vbs_request = DebtManagementCenter::VBS::Request.build
      Rails.logger.info('5655 Form Submitting to VBS API', submission_id: form_submission.id)
      measure_latency("#{STATSD_KEY_PREFIX}.fsr.submit.vbs.latency") do
        vbs_request.post("#{vbs_settings.base_path}/UploadFSRJsonDocument",
                         { jsonDocument: form.to_json })
      end
    end

    def send_vha_confirmation_email(_status, options)
      return if Flipper.enabled?(:fsr_zero_silent_errors_in_progress_email)
      return if options['cache_key'].blank?

      DebtManagementCenter::VANotifyEmailJob.perform_async(
        nil,
        options['template_id'],
        nil,
        { id_type: 'email', failure_mailer: false, cache_key: options['cache_key'] }
      )
    end

    private

    def add_vha_specific_data(form_submission)
      form = form_submission.form
      form['transactionId'] = form_submission.id
      form['timestamp'] = form_submission.created_at.strftime('%Y%m%dT%H%M%S')
      form
    end

    def build_public_metadata(form_builder, form, debts)
      begin
        enabled_flags = Flipper.features.select { |feature| feature.enabled?(@user) }.map do |feature|
          feature.name.to_s
        end.sort
      rescue => e
        Rails.logger.error('Failed to source user flags', e.message)
        enabled_flags = []
      end
      debt_amounts = debts.nil? ? [] : debts.map { |debt| debt['currentAR'] || debt['pHAmtDue'] }
      debt_type = debts&.pick('debtType')
      {
        'combined' => form_builder.is_combined,
        'debt_amounts' => debt_amounts,
        'debt_type' => debt_type,
        'flags' => enabled_flags,
        'streamlined' => form_builder.streamlined_data,
        'zipcode' => form.dig('personalData', 'address', 'zipOrPostalCode') || '???'
      }
    end

    def persist_vha_form_submission(fsr_builder)
      fsr_builder.vha_forms.map(&:persist_form_submission)
    end

    def persist_vba_form_submission(fsr_builder)
      fsr_builder.vba_form.persist_form_submission
    end

    def submit_vha_batch_job(vha_submissions)
      return unless defined?(Sidekiq::Batch)

      StatsD.increment("#{DebtsApi::V0::Form5655::VHA::VBSSubmissionJob::STATS_KEY}.initiated")

      submission_batch = Sidekiq::Batch.new
      email = @user.email&.downcase
      if email.present?
        template = vha_submissions.any?(&:streamlined?) ? STREAMLINED_CONFIRMATION_TEMPLATE : VHA_CONFIRMATION_TEMPLATE
        cache_key = Sidekiq::AttrPackage.create(
          email:,
          personalisation: email_personalization_info
        )
        submission_batch.on(
          :success,
          'DebtsApi::V0::FinancialStatusReportService#send_vha_confirmation_email',
          'cache_key' => cache_key,
          'template_id' => template
        )
      end
      submission_batch.jobs do
        vha_submissions.map(&:submit_to_vha)
      end
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
        log_exception_to_rails(e)
      end
    end

    def validate_form_schema(form)
      schema_path = Rails.root.join('lib', 'debt_management_center', 'schemas', 'fsr.json').to_s
      errors = JSON::Validator.fully_validate(schema_path, form)

      if errors.any?
        Rails.logger.error("DebtsApi::V0::FinancialStatusReportService validation failed: #{errors}")
        raise FSRInvalidRequest
      end
    end

    def send_confirmation_email(template_id)
      return unless Settings.vsp_environment == 'production'

      email = @user.email&.downcase
      return if email.blank?

      cache_key = Sidekiq::AttrPackage.create(
        email:,
        personalisation: email_personalization_info
      )
      DebtManagementCenter::VANotifyEmailJob.perform_async(
        nil, template_id, nil, { id_type: 'email', cache_key: }
      )
    end

    def email_personalization_info
      { 'name' => @user.first_name, 'time' => '48 hours', 'date' => Time.zone.now.strftime('%m/%d/%Y') }
    end

    def vbs_settings
      Settings.mcp.vbs_v2
    end
  end
end
