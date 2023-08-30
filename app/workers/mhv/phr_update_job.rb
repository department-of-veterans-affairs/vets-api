# frozen_string_literal: true

require 'medical_records/phr_mgr/client'

##
# For current MHV users, call the "PHR Refresh" API in MHV to update their medical records in the
# FHIR server. This is done on login to give the process time to complete before the user browses
# to the medical records page.
#
module MHV
  class PhrUpdateJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(icn, mhv_correlation_id)
      run_refresh(icn) if mhv_user?(mhv_correlation_id)
    rescue => e
      handle_errors(e)
    end

    private

    def run_refresh(icn)
      phr_client = PHRMgr::Client.new
      phr_client.post_phrmgr_refresh(icn)
    end

    def mhv_user?(mhv_correlation_id)
      mhv_correlation_id.present?
    end

    def handle_errors(e)
      Rails.logger.error("MHV PHR refresh failed: #{e.message}", e)
    end
  end
end
