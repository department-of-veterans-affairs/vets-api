# frozen_string_literal: true

module Vye
  class DawnDash
    class EgressUpdates
      include Sidekiq::Job
      sidekiq_options retry: 0

      def perform
        Vye::CloudTransfer.log_current_time_info

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
    end
  end
end
