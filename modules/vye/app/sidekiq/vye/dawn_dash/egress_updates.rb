# frozen_string_literal: true

module Vye
  class DawnDash
    class EgressUpdates
      include Sidekiq::Job
      sidekiq_options retry: 0

      def perform
        log_current_time_info

        if Vye::CloudTransfer.holiday?
          logger.info("Vye::DawnDash::ActivateBdn: holiday detected, job run at: #{Time.zone.now}")
          return
        end

        logger.info('Vye::DawnDash::EgressUpdates: No holiday detected, proceeding with file uploads')

        Vye::BatchTransfer::EgressFiles.address_changes_upload
        Vye::BatchTransfer::EgressFiles.direct_deposit_upload
        Vye::BatchTransfer::EgressFiles.verification_upload
        BdnClone.clear_export_ready!
      end

      private

      def log_current_time_info
        logger.info("Vye::DawnDash::EgressUpdates: Job started at: #{Time.zone.now}")
        logger.info("Vye::DawnDash::EgressUpdates: Current Rails.env: #{Rails.env}")
        logger.info("Vye::DawnDash::EgressUpdates: Current Time.zone: #{Time.zone}")
        logger.info("Vye::DawnDash::EgressUpdates: Current Time.zone.now: #{Time.zone.now}")
        logger.info("Vye::DawnDash::EgressUpdates: Current Time.now (system): #{Time.now}")
        logger.info("Vye::DawnDash::EgressUpdates: Current Time.now.utc: #{Time.now.utc}")

        us_holidays = Holidays.on(Time.zone.today, :us, :observed)
        logger.info("Vye::DawnDash::EgressUpdates: US holidays today: #{us_holidays.inspect}")

        # Directly check for holiday with holiday? method - for comparison with our manual check
        is_holiday = Vye::CloudTransfer.holiday?
        logger.info("Vye::DawnDash::EgressUpdates: Vye::CloudTransfer.holiday? returned: #{is_holiday}")
      end
    end
  end
end
