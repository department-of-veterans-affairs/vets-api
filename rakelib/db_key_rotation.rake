# frozen_string_literal: true

require 'database/key_rotation'
require 'sentry_logging'

# This iterates over each record (with attrs encrypted via attr_encrypted)
# decrypts with the old key, re-saves and encrypts with the new key
# any new db fields using attr_encrypted will need to be
# added to this rake task

namespace :attr_encrypted do
  desc 'Rotate the encryption keys'
  task rotate_keys: :environment do
    # overriding/monkey patching the encryption_key method
    # in order to rotate the Settings.db_encryption_key
    module Database
      module KeyRotation
        def encryption_key(attribute)
          if is_decrypting?(attribute)
            Settings.old_db_encryption_key
          else
            Settings.db_encryption_key
          end
        end
      end
    end

    ActiveRecord::Base.transaction do
      AppealSubmission.all.each do |submission|
        old_metadata = submission.upload_metadata
        submission.upload_metadata = old_metadata
        submission.save!
      end

      EducationStemAutomatedDecision.all.each do |esad|
        old_auth_headers_json = esad.auth_headers_json
        esad.auth_headers_json = old_auth_headers_json
        esad.save!
      end

      Form526Submission.all.each do |form_526_sub|
        old_auth_headers_json = form_526_sub.auth_headers_json
        form_526_sub.auth_headers_json = old_auth_headers_json

        old_form_json = form_526_sub.form_json
        form_526_sub.form_json = old_form_json

        old_birls_ids_tried = form_526_sub.birls_ids_tried
        form_526_sub.birls_ids_tried = old_birls_ids_tried

        form_526_sub.save!
      end

      FormAttachment.all.each do |form_attachment|
        old_file_data = form_attachment.file_data
        form_attachment.file_data = old_file_data
        form_attachment.save!
      end

      GibsNotFoundUser.all.each do |r|
        old_ssn = r.ssn
        r.ssn = old_ssn
        r.save!
      end

      InProgressForm.all.each do |in_progress_form|
        old_form_data = in_progress_form.form_data
        in_progress_form.form_data = old_form_data
        in_progress_form.save!
      end

      PersistentAttachment.all.each do |pa|
        old_file_data = pa.file_data
        pa.file_data = old_file_data
        pa.save!
      end

      # SavedClaim
      # the attr_encrypted form field lives on the SavedClaim model
      # all of the below class inherit from SavedClaim
      saved_claim_types = [
        CentralMailClaim,
        SavedClaim::EducationBenefits,
        SavedClaim::Ask,
        SavedClaim::CaregiversAssistanceClaim,
        SavedClaim::DependencyClaim,
        SavedClaim::DisabilityCompensation,
        SavedClaim::EducationBenefits,
        SavedClaim::VeteranReadinessEmploymentClaim
      ]

      saved_claim_types.each do |claim_type|
        claim_type.all.each do |saved_claim|
          old_form = saved_claim.form
          saved_claim.form = old_form
          saved_claim.save!
        end
      end

      AsyncTransaction::Base.all.each do |at|
        old_metadata = at.metadata
        at.metadata = old_metadata
        at.save!
      end

      AppealsApi::HigherLevelReview.all.each do |hlr|
        old_form_data = hlr.form_data
        hlr.form_data = old_form_data

        old_auth_headers = hlr.auth_headers
        hlr.auth_headers = old_auth_headers

        hlr.save!
      end

      AppealsApi::NoticeOfDisagreement.all.each do |nod|
        old_form_data = nod.form_data
        nod.form_data = old_form_data

        old_auth_headers = nod.auth_headers
        nod.auth_headers = old_auth_headers

        nod.save!
      end

      ClaimsApi::AutoEstablishedClaim.all.each do |aec|
        old_form_data = aec.form_data
        aec.form_data = old_form_data

        old_file_data = aec.file_data
        aec.file_data = old_file_data

        old_auth_headers = aec.auth_headers
        aec.auth_headers = old_auth_headers

        old_evss_response = aec.evss_response
        aec.evss_response = old_evss_response

        old_bgs_flash_responses = aec.bgs_flash_responses
        aec.bgs_flash_responses = old_bgs_flash_responses

        old_special_issue_repsonses = aec.bgs_special_issue_responses
        aec.bgs_special_issue_responses = old_special_issue_repsonses

        aec.save!
      end

      ClaimsApi::PowerOfAttorney.all.each do |poa|
        old_form_data = poa.form_data
        poa.form_data = old_form_data

        old_file_data = poa.file_data
        poa.file_data = old_file_data

        old_auth_headers = poa.auth_headers
        poa.auth_headers = old_auth_headers

        old_source_data = poa.source_data
        poa.source_data = old_source_data

        poa.save!
      end

      ClaimsApi::SupportingDocument.all.each do |sd|
        old_file_data = sd.file_data
        sd.file_data = old_file_data

        sd.save!
      end

      CovidVaccine::V0::ExpandedRegistrationSubmission.all.each do |ers|
        old_form_data = ers.form_data
        ers.form_data = old_form_data

        old_raw_form_data = ers.raw_form_data
        ers.raw_form_data = old_raw_form_data

        old_eligibility_info = ers.eligibility_info
        ers.eligibility_info = old_eligibility_info

        ers.save!
      end

      CovidVaccine::V0::RegistrationSubmission.all.each do |rs|
        old_form_data = rs.form_data
        rs.form_data = old_form_data

        old_raw_form_data = rs.raw_form_data
        rs.raw_form_data = old_raw_form_data

        rs.save!
      end

      HealthQuest::QuestionnaireResponse.all.each do |qs|
        old_questionnaire_response_data = qs.questionnaire_response_data
        qs.questionnaire_response_data = old_questionnaire_response_data

        old_user_demographics_data = qs.user_demographics_data
        qs.user_demographics_data = old_user_demographics_data

        qs.save!
      end

      Veteran::Service::Representative.all.each do |vsr|
        old_ssn = vsr.ssn
        vsr.ssn = old_ssn

        old_dob = vsr.dob
        vsr.dob = old_dob

        vsr.save!
      end
    rescue => e
      puts "....rolling back transaction. Error occured: #{e.inspect}"
      Rails.logger.error("Error running the db key rotation rake task, rolling back: #{e}")
      raise ActiveRecord::Rollback # makes sure the transaction gets completely rolled back
    end
  end
end
