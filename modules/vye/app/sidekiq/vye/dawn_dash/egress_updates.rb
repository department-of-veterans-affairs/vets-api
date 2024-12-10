# frozen_string_literal: true

require_relative '../helpers'

module Vye
  class DawnDash
    class EgressUpdates
      include Sidekiq::Job
      sidekiq_options retry: 0

      def perform
        return if holiday?

        Vye::BatchTransfer::EgressFiles.address_changes_upload
        Vye::BatchTransfer::EgressFiles.direct_deposit_upload
        Vye::BatchTransfer::EgressFiles.verification_upload
        BdnClone.clear_export_ready!
      end
    end
  end
end
