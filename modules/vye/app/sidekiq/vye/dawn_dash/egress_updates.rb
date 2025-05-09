# frozen_string_literal: true

module Vye
  class DawnDash
    class EgressUpdates
      include Sidekiq::Job
      sidekiq_options retry: 0

      def log_current_time_info
        Rails.logger.info("Vye::DawnDash::EgressUpdates: Job started at: #{Time.zone.now}")
        Rails.logger.info("Vye::DawnDash::EgressUpdates: Current Time.zone: #{Time.zone}")

        us_holidays = Holidays.on(Time.zone.today, :us, :observed)
        Rails.logger.info("Vye::DawnDash::EgressUpdates: US holidays today: #{us_holidays.inspect}")

        is_holiday = Vye::CloudTransfer.holiday?
        Rails.logger.info("Vye::DawnDash::EgressUpdates: Vye::CloudTransfer.holiday? returned: #{is_holiday}")
      end

      def perform
        log_current_time_info

        if Vye::CloudTransfer.holiday?
          logger.info("Vye::DawnDash::EgressUpdates: holiday detected, job run at: #{Time.zone.now}")
          return
        end

        logger.info('Vye::DawnDash::EgressUpdates: No holiday detected, proceeding with file uploads')

        Vye::BatchTransfer::EgressFiles.address_changes_upload
        Vye::BatchTransfer::EgressFiles.direct_deposit_upload
        Vye::BatchTransfer::EgressFiles.verification_upload
        BdnClone.clear_export_ready!
      end
    end
  end
end
