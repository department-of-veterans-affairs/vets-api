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
        next
      end

      # if the claim has autoCestPDFGenerationDisabled set as false, we need to upload the 526EZ PDF
      if claim.form_data.present? && claim.form_data['autoCestPDFGenerationDisabled'] == false

        # DisabilityCompensationPdfGenerator is used for POST request with FES enabled.
        if Flipper.enabled?(:lighthouse_claims_api_v1_enable_FES)
          # use header info to get veteran info from MPI

          mpi_profile = MPI::Service.new.find_profile_by_attributes(
            first_name: claim.auth_headers['va_eauth_firstName'],
            last_name: claim.auth_headers['va_eauth_lastName'],
            birth_date: claim.auth_headers['va_eauth_birthdate']&.to_date&.to_s,
            ssn: claim.auth_headers['va_eauth_pnid']
          )&.profile
          middle_name = mpi_profile&.given_names&.second

          # middle initial can be nil or 'Null' in MPI, so check for both cases before assigning value to variable
          middle_initial = if mpi_profile&.given_names&.second.blank? ||
                              mpi_profile&.given_names&.second&.downcase == 'null'
                             ''
                           else
                             middle_name[0]
                           end

          Logger.info("Sending claim #{claim_id} to DisabilityCompensationPdfGenerator job")
          ClaimsApi::V1::DisabilityCompensationPdfGenerator.perform_inline(claim.id, middle_initial)
        else
          Logger.info("Sending claim #{claim_id} to ClaimEstablisher job")
          ClaimsApi::ClaimEstablisher.perform_inline(claim.id)
        end

      elsif claim.form_data.present? && claim.form_data['autoCestPDFGenerationDisabled'] == true
        # if FES enabled, use Form526EstablishmentUpload service
        if Flipper.enabled?(:lighthouse_claims_api_v1_enable_FES)
          Logger.info("Sending claim #{claim_id} to Form526EstablishmentUpload job")
          ClaimsApi::Form526EstablishmentUpload.perform_inline(claim.id)
        # else use ClaimEstablisher and ClaimUploader
        else
          Logger.info("Sending claim #{claim_id} to ClaimEstablisher job")
          ClaimsApi::ClaimEstablisher.perform_inline(claim.id)
          Logger.info("Sending claim #{claim_id} to ClaimUploader job")
          ClaimsApi::ClaimUploader.perform_inline(claim.id, 'claim')
        end

      else
        Rails.logger.warn(
          "Claim #{claim_id} is missing form_data or autoCestPDFGenerationDisabled flag, skipping PDF generation"
        )
      end

      # reload and verify claim was established
      claim.reload
      raise 'Claim establishment failed' if claim.status == ClaimsApi::AutoEstablishedClaim::ERRORED

      Rails.logger.info("Successfully reestablished claim #{claim_id} with evss id #{claim.evss_id}")

      # upload each supporting document in the claim
      claim.supporting_documents.each do |sup|
        Rails.logger.info("Uploading supporting document #{sup.id} for claim #{claim_id}")
        ClaimsApi::ClaimUploader.perform_inline(sup.id, 'document')
      end
    rescue => e
      # display error and continue
      Rails.logger.error("Error processing claim #{claim_id}: #{e.class} - #{e.message}")
      next
    end
  end
end
