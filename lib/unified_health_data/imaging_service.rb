# frozen_string_literal: true

require 'common/client/base'
require_relative 'adapters/imaging_study_adapter'
require_relative 'client'

module UnifiedHealthData
  class ImagingService
    STATSD_KEY_PREFIX = 'api.uhd'
    include Common::Client::Concerns::Monitoring

    def initialize(user)
      super()
      @user = user
    end

    def get_imaging_studies(start_date:, end_date:, imaging_study_type: 'ALL', site_ids: [])
      with_monitoring do
        response = uhd_client.get_imaging_studies(
          patient_id: @user.icn,
          start_date:,
          end_date:,
          imaging_study_type:,
          site_ids:
        )
        records = response.body['entry'] || []
        log_operation_outcomes(records)
        imaging_study_adapter.parse(records)
      end
    end

    def get_imaging_study(start_date:, end_date:, record_id:)
      with_monitoring do
        response = uhd_client.get_imaging_study(
          patient_id: @user.icn,
          start_date:,
          end_date:,
          record_id:
        )
        records = response.body['entry'] || []
        imaging_study_adapter.parse(records)
      end
    end

    def get_dicom_zip(start_date:, end_date:, record_id:)
      with_monitoring do
        response = uhd_client.get_dicom_zip(
          patient_id: @user.icn,
          start_date:,
          end_date:,
          record_id:
        )
        records = response.body['entry'] || []
        imaging_study_adapter.parse(records)
      end
    end

    private

    def uhd_client
      @uhd_client ||= UnifiedHealthData::Client.new
    end

    def imaging_study_adapter
      @imaging_study_adapter ||= UnifiedHealthData::Adapters::ImagingStudyAdapter.new
    end

    # Logs any OperationOutcome entries in the response for observability.
    # SCDF returns OperationOutcome with severity: warning for partial failures
    # (e.g., when one site fails while another succeeds).
    def log_operation_outcomes(records)
      outcomes = records.select { |r| r.dig('resource', 'resourceType') == 'OperationOutcome' }
      outcomes.each do |outcome|
        issues = outcome.dig('resource', 'issue') || []
        issues.each do |issue|
          next if issue['severity'] == 'information'

          Rails.logger.warn(
            message: 'UHD imaging OperationOutcome detected',
            severity: issue['severity'],
            code: issue['code'],
            diagnostics: issue['diagnostics']
          )
        end
      end
    end
  end
end
