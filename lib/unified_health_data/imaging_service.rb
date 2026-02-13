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

    def get_imaging_studies(start_date:, end_date:, imaging_study_type: 'ALL')
      with_monitoring do
        response = uhd_client.get_imaging_studies(
          patient_id: @user.icn,
          start_date:,
          end_date:,
          imaging_study_type:
        )
        imaging_study_adapter.parse(response.body)
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
        imaging_study_adapter.parse(response.body)
      end
    end

    private

    def uhd_client
      @uhd_client ||= UnifiedHealthData::Client.new
    end

    def imaging_study_adapter
      @imaging_study_adapter ||= UnifiedHealthData::Adapters::ImagingStudyAdapter.new
    end
  end
end
