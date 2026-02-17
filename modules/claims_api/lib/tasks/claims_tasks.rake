# frozen_string_literal: true

namespace :claims do
  task :export, %i[start end] => :environment do |_task, args|
    start_at = args[:start].present? ? Time.parse(args[:start]).utc : Time.at(0).utc
    end_at = args[:end].present? ? Time.parse(args[:end]).utc : Time.now.utc

    claims = ClaimsApi::AutoEstablishedClaim.where.not(evss_id: nil)
    claims = claims.where('created_at >= ? and created_at <= ?', start_at, end_at)
    puts 'id,evss_id,has_flashes,has_special_issues'
    claims.each { |claim| puts "#{claim.id},#{claim.evss_id},#{claim.flashes.any?},#{claim.special_issues.any?}" }
  end

  task update_poa_md5: :environment do
    power_of_attorneys = ClaimsApi::PowerOfAttorney.all
    # save! reruns validations, which includes set_md5
    power_of_attorneys.each(&:save!)
  end

  # rake task used in production to fix 526 claims that failed to establish.
  task :fix_failed_claims, [:claim_ids] => :environment do |_task, args|
    # helper method to wait for claim to be established or errored before proceeding with next steps in the task
    wait_for_establishment = lambda do |claim, timeout: 10.seconds, interval: 2|
      deadline = Time.current + timeout
      loop do
        claim.reload
        break if claim.status != ClaimsApi::AutoEstablishedClaim::ERRORED

        raise "Timed out waiting for claim #{claim.id} to establish" if Time.current >= deadline

        sleep interval
      end
    end

    args[:claim_ids] ||= []
    claim_ids = Array(args[:claim_ids])
    # Handle comma-separated claim IDs
    claim_ids = claim_ids.flat_map { |id| id.split(',').map(&:strip) }
    claim_ids.each do |claim_id|
      # validate claim exists before attempting to reestablish, if not skip to next claim
      claim = ClaimsApi::AutoEstablishedClaim.find_by(id: claim_id)
      unless claim
        Rails.logger.warn("Could not find claim with id #{claim_id}")
        next
      end

      # guard clause to skip claims that are not in an errored state
      next if claim.status != ClaimsApi::AutoEstablishedClaim::ERRORED

      # resubmitting claim establishment job for the claim
      ClaimsApi::ClaimEstablisher.perform_async(claim.id)

      # wait for the claim to be established or errored before proceeding
      wait_for_establishment.call(claim)

      # validate claim is established or raise an error if still errored
      if claim.status == ClaimsApi::AutoEstablishedClaim::ERRORED
        raise ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity.new(
          detail: "Claim establishment failed for claim ID #{claim.id} with error: #{claim.evss_response}"
        )
      end

      # upload 526EZ PDF per claim
      ClaimsApi::ClaimUploader.perform_async(claim.id, 'claim')
      # upload each supporting document in the claim
      claim.supporting_documents.each do |sup|
        ClaimsApi::ClaimUploader.perform_async(sup.id, 'document')
      end
    end
  end
end
