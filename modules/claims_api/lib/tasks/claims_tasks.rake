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
  # matches PUT and POST request in disability_compensation_controller.rb (upload_form_526, and submit_form_526)
  task :fix_failed_claims, [:claim_ids] => :environment do |_task, args|
    # helper method to wait for claim to be established or errored before proceeding with next steps in the task
    wait_for_establishment = lambda do |claim, timeout: 30.seconds, interval: 2|
      deadline = Time.current + timeout
      loop do
        claim.reload
        break if claim.status != ClaimsApi::AutoEstablishedClaim::ERRORED

        # if the claim is still errored, raise since the job likely failed
        if Time.current >= deadline
          raise StandardError, "Claim establishment failed for claim ID #{claim.id} with error: #{claim.evss_response}"
        end

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
      if claim.status != ClaimsApi::AutoEstablishedClaim::ERRORED
        Rails.logger.info("skipping claim #{claim_id} due to status #{claim.status}")
      end

      # prompt the user to enter if the failed request came from POST of PUT endpoint
      puts "Claim ID #{claim_id} is in an errored state. Did the failed request come from the PUT endpoint?"
      puts 'i.e do you need to create and upload a 526EZ PDF (y/n)'
      response = $stdin.gets.chomp.downcase
      unless %w[y n].include?(response)
        puts 'Invalid response. Please enter y or n.'
        next
      end

      # DisabilityCompensationPdfGenerator is used for POST request with FES enabled.
      if Flipper.enabled?(:lighthouse_claims_api_v1_enable_FES) && response == 'n'
        # Attempt to get veteran middle initial from form data alternateNames
        # alternateNames is an array, so find the first entry with a middle name and extract the initial
        alternate_names = claim.form_data.dig('serviceInformation', 'alternateNames') || []
        veteran_middle_initial = alternate_names.find do |name|
          name['middleName'].present?
        end&.dig('middleName')&.first&.upcase || ''

        ClaimsApi::V1::DisabilityCompensationPdfGenerator.perform_async(claim.id, veteran_middle_initial)
      else
        ClaimsApi::ClaimEstablisher.perform_async(claim.id)
      end

      # wait for the claim to be established or errored before proceeding
      # if the claim is still errored, it will fail here
      wait_for_establishment.call(claim)

      # if yes to PUT request, upload the 526EZ PDF
      ClaimsApi::ClaimUploader.perform_async(claim.id, 'claim') unless response == 'n'

      # upload each supporting document in the claim
      claim.supporting_documents.each do |sup|
        ClaimsApi::ClaimUploader.perform_async(sup.id, 'document')
      end
    end
  end
end
