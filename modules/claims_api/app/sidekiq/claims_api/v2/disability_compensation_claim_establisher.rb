# frozen_string_literal: true

module ClaimsApi
  module V2
    class DisabilityCompensationClaimEstablisher < DisabilityCompensationClaimServiceBase
      # Mark as established, set flashes and special issues
      def perform(claim_id)
        log_job_progress('526 v2 Claim Establisher job',
                         claim_id,
                         'Beginning 526 v2 Claim Establisher job')

        auto_claim = get_claim(claim_id)

        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        queue_flash_updater(auto_claim.flashes, auto_claim&.id)
        queue_special_issues_updater(auto_claim.special_issues, auto_claim)

        set_established_state_on_claim(auto_claim)

        log_job_progress('526 v2 Claim Establisher job',
                         claim_id,
                         'Disablity compensation claim establisher job completed')
      rescue => e
        set_errored_state_on_claim(claim)
        log_job_progress('526 v2 Claim Establisher job',
                         claim_id,
                         "Disablity compensation claim establisher job error: #{e}")
        log_exception_to_sentry(e)

        raise e
      end

      private

      def queue_special_issues_updater(special_issues_per_disability, auto_claim)
        return if special_issues_per_disability.blank?

        special_issues_per_disability.each do |disability|
          contention_id = {
            claim_id: auto_claim.evss_id,
            code: disability['code'],
            name: disability['name']
          }
          ClaimsApi::SpecialIssueUpdater.perform_async(contention_id,
                                                       disability['special_issues'],
                                                       auto_claim&.id)
        end
      end

      def queue_flash_updater(flashes, auto_claim_id)
        return if flashes.blank?

        ClaimsApi::FlashUpdater.perform_async(flashes, auto_claim_id)
      end

      def set_claim_as_established(auto_claim)
        auto_claim.status = ClaimsApi::AutoEstablishedClaim::ESTABLISHED
        auto_claim.evss_response = nil
        auto_claim.save!
      end
    end
  end
end
