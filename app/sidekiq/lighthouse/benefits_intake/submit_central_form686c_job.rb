# frozen_string_literal: true

require 'central_mail/service'
require 'benefits_intake_service/service'
require 'pdf_utilities/datestamp_pdf'
require 'pdf_info'
require 'simple_forms_api_submission/metadata_validator'
require 'dependents/monitor'

module Lighthouse
  module BenefitsIntake
    class SubmitCentralForm686cJob
      include Sidekiq::Job
      include SentryLogging

      FOREIGN_POSTALCODE = '00000'
      FORM_ID = '686C-674'
      FORM_ID_V2 = '686C-674-V2'
      FORM_ID_674 = '21-674'
      FORM_ID_674_V2 = '21-674-V2'
      STATSD_KEY_PREFIX = 'worker.submit_686c_674_backup_submission'
      ZSF_DD_TAG_FUNCTION = 'submit_686c_674_backup_submission'
      # retry for  2d 1h 47m 12s
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
      RETRY = 16

      attr_reader :claim, :form_path, :attachment_paths

      class BenefitsIntakeResponseError < StandardError; end

      def extract_uuid_from_central_mail_message(data)
        data.body[/(?<=\[).*?(?=\])/].split(': ').last if data.body.present?
      end

      sidekiq_options retry: RETRY

      sidekiq_retries_exhausted do |msg, _ex|
        if Flipper.enabled?(:dependents_trigger_action_needed_email)
          Lighthouse::BenefitsIntake::SubmitCentralForm686cJob.trigger_failure_events(msg)
        end
      end

      def perform(saved_claim_id, encrypted_vet_info, encrypted_user_struct)
        vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
        user_struct = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user_struct))
        # if the 686c-674 has failed we want to call this central mail job (credit to submit_saved_claim_job.rb)
        # have to re-find the claim and add the relevant veteran info
        Rails.logger.info('Lighthouse::BenefitsIntake::SubmitCentralForm686cJob running!',
                          { user_uuid: user_struct['uuid'], saved_claim_id:, icn: user_struct['icn'] })
        @claim = SavedClaim::DependencyClaim.find(saved_claim_id)
        claim.add_veteran_info(vet_info)

        get_files_from_claim(user_struct)
        result = upload_to_lh(user_struct)
        check_success(result, saved_claim_id, user_struct)
      rescue => e
        # if we fail, update the associated central mail record to failed and send the user the failure email
        Rails.logger.warn('Lighthouse::BenefitsIntake::SubmitCentralForm686cJob failed!',
                          { user_uuid: user_struct['uuid'], saved_claim_id:, icn: user_struct['icn'], error: e.message }) # rubocop:disable Layout/LineLength
        update_submission('failed')
        raise
      ensure
        cleanup_file_paths
      end

      def upload_to_lh(user_struct)
        Rails.logger.info({ message: 'SubmitCentralForm686cJob Lighthouse Initiate Submission Attempt',
                            claim_id: claim.id })
        lighthouse_service = BenefitsIntakeService::Service.new(with_upload_location: true)
        uuid = lighthouse_service.uuid
        Rails.logger.info({ message: 'SubmitCentralForm686cJob Lighthouse Submission Attempt', claim_id: claim.id,
                            uuid: })
        response = lighthouse_service.upload_form(
          main_document: split_file_and_path(form_path),
          attachments: attachment_paths.map(&method(:split_file_and_path)),
          form_metadata: generate_metadata_lh
        )
        create_form_submission_attempt(uuid, user_struct)

        Rails.logger.info({ message: 'SubmitCentralForm686cJob Lighthouse Submission Successful', claim_id: claim.id,
                            uuid: })
        response
      end

      def create_form_submission_attempt(intake_uuid, user_struct)
        v2 = user_struct['v2']
        form_type = if v2
                      claim.submittable_686? ? FORM_ID_V2 : FORM_ID_674_V2
                    else
                      claim.submittable_686? ? FORM_ID : FORM_ID_674
                    end
        FormSubmissionAttempt.transaction do
          form_submission = FormSubmission.create(
            form_type:,
            saved_claim: claim,
            user_account: UserAccount.find_by(icn: claim.parsed_form['veteran_information']['icn'])
          )
          FormSubmissionAttempt.create(form_submission:, benefits_intake_uuid: intake_uuid)
        end
      end

      def get_files_from_claim(user_struct)
        # process the main pdf record and the attachments as we would for a vbms submission
        v2 = user_struct['v2']
        if claim.submittable_674?
          form_674_paths = []
          if v2
            claim.parsed_form['dependents_application']['student_information'].each do |student|
              form_674_paths << process_pdf(claim.to_pdf(form_id: FORM_ID_674_V2, student:), claim.created_at, FORM_ID_674_V2) # rubocop:disable Layout/LineLength
            end
          else
            form_674_paths << process_pdf(claim.to_pdf(form_id: FORM_ID_674), claim.created_at, FORM_ID_674)
          end
        end
        form_id = v2 ? FORM_ID_V2 : FORM_ID
        form_686c_path = process_pdf(claim.to_pdf(form_id:), claim.created_at, form_id) if claim.submittable_686?
        # set main form_path to be first 674 in array if needed
        @form_path = form_686c_path || form_674_paths.first

        @attachment_paths = claim.persistent_attachments.map { |pa| process_pdf(pa.to_pdf, claim.created_at) }
        # Treat 674 as first attachment
        if form_686c_path.present? && form_674_paths.present?
          attachment_paths.unshift(*form_674_paths)
        elsif form_674_paths.present? && form_674_paths.size > 1
          attachment_paths.unshift(*form_674_paths.drop(1))
        end
      end

      def cleanup_file_paths
        Common::FileHelpers.delete_file_if_exists(form_path)
        attachment_paths.each { |p| Common::FileHelpers.delete_file_if_exists(p) }
      end

      def check_success(response, saved_claim_id, user_struct)
        if response.success?
          Rails.logger.info('Lighthouse::BenefitsIntake::SubmitCentralForm686cJob succeeded!',
                            { user_uuid: user_struct['uuid'], saved_claim_id:, icn: user_struct['icn'] })
          update_submission('success')
          send_confirmation_email(OpenStruct.new(user_struct))
        else
          Rails.logger.info('Lighthouse::BenefitsIntake::SubmitCentralForm686cJob Unsuccessful',
                            { response: response['message'].presence || response['errors'] })
          raise BenefitsIntakeResponseError
        end
      end

      def create_request_body
        body = {
          'metadata' => generate_metadata.to_json
        }

        body['document'] = to_faraday_upload(form_path)

        i = 0
        attachment_paths.each do |file_path|
          body["attachment#{i += 1}"] = to_faraday_upload(file_path)
        end

        body
      end

      def update_submission(state)
        claim.central_mail_submission.update!(state:) if claim.respond_to?(:central_mail_submission)
      end

      def to_faraday_upload(file_path)
        Faraday::UploadIO.new(
          file_path,
          Mime[:pdf].to_s
        )
      end

      def process_pdf(pdf_path, timestamp = nil, form_id = nil)
        stamped_path1 = PDFUtilities::DatestampPdf.new(pdf_path).run(text: 'VA.GOV', x: 5, y: 5, timestamp:)
        stamped_path2 = PDFUtilities::DatestampPdf.new(stamped_path1).run(
          text: 'FDC Reviewed - va.gov Submission',
          x: 400,
          y: 770,
          text_only: true
        )
        if form_id.present?
          stamped_pdf_with_form(form_id, stamped_path2, timestamp)
        else
          stamped_path2
        end
      end

      def get_hash_and_pages(file_path)
        {
          hash: Digest::SHA256.file(file_path).hexdigest,
          pages: PdfInfo::Metadata.read(file_path).pages
        }
      end

      def generate_metadata(user_struct) # rubocop:disable Metrics/MethodLength
        form = claim.parsed_form['dependents_application']
        veteran_information = form['veteran_information'].presence || claim.parsed_form['veteran_information']
        form_pdf_metadata = get_hash_and_pages(form_path)
        address = form['veteran_contact_information']['veteran_address']
        is_usa = address['country_name'] == 'USA'
        v2 = user_struct['v2']
        zip_code = v2 ? address['postal_code'] : address['zip_code']
        metadata = {
          'veteranFirstName' => veteran_information['full_name']['first'],
          'veteranLastName' => veteran_information['full_name']['last'],
          'fileNumber' => veteran_information['file_number'] || veteran_information['ssn'],
          'receiveDt' => claim.created_at.in_time_zone('Central Time (US & Canada)').strftime('%Y-%m-%d %H:%M:%S'),
          'uuid' => claim.guid,
          'zipCode' => is_usa ? zip_code : FOREIGN_POSTALCODE,
          'source' => 'va.gov',
          'hashV' => form_pdf_metadata[:hash],
          'numberAttachments' => attachment_paths.size,
          'docType' => claim.form_id,
          'numberPages' => form_pdf_metadata[:pages]
        }

        validated_metadata = SimpleFormsApiSubmission::MetadataValidator.validate(
          metadata,
          zip_code_is_us_based: is_usa
        )

        validated_metadata.merge(generate_attachment_metadata(attachment_paths))
      end

      def generate_metadata_lh
        form = claim.parsed_form['dependents_application']
        # sometimes veteran_information is not in dependents_application, but claim.add_veteran_info will make sure
        # it's in the outer layer of parsed_form
        veteran_information = form['veteran_information'].presence || claim.parsed_form['veteran_information']
        address = form['veteran_contact_information']['veteran_address']
        {
          veteran_first_name: veteran_information['full_name']['first'],
          veteran_last_name: veteran_information['full_name']['last'],
          file_number: veteran_information['file_number'] || veteran_information['ssn'],
          zip: address['country_name'] == 'USA' ? address['zip_code'] : FOREIGN_POSTALCODE,
          doc_type: claim.form_id,
          claim_date: claim.created_at,
          source: 'va.gov backup dependent claim submission',
          business_line: 'CMP'
        }
      end

      def generate_attachment_metadata(attachment_paths)
        attachment_metadata = {}
        i = 0
        attachment_paths.each do |file_path|
          i += 1
          attachment_pdf_metadata = get_hash_and_pages(file_path)
          attachment_metadata["ahash#{i}"] = attachment_pdf_metadata[:hash]
          attachment_metadata["numberPages#{i}"] = attachment_pdf_metadata[:pages]
        end
        attachment_metadata
      end

      def send_confirmation_email(user)
        return claim.send_received_email(user) if Flipper.enabled?(:dependents_separate_confirmation_email)

        return if user.va_profile_email.blank?

        form_id = user.v2 ? FORM_ID_V2 : FORM_ID
        VANotify::ConfirmationEmail.send(
          email_address: user.va_profile_email,
          template_id: Settings.vanotify.services.va_gov.template_id.form686c_confirmation_email,
          first_name: user&.first_name&.upcase,
          user_uuid_and_form_id: "#{user.uuid}_#{form_id}"
        )
      end

      def self.trigger_failure_events(msg)
        saved_claim_id, _, encrypted_user_struct = msg['args']
        user_struct = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user_struct)) if encrypted_user_struct.present?
        claim = SavedClaim::DependencyClaim.find(saved_claim_id)
        email = claim.parsed_form.dig('dependents_application', 'veteran_contact_information', 'email_address') ||
                user_struct.try(:va_profile_email)
        Dependents::Monitor.new(claim.id).track_submission_exhaustion(msg, email)
        claim.send_failure_email(email)
      rescue => e
        # If we fail in the above failure events, this is a critical error and silent failure.
        v2 = claim&.use_v2
        Rails.logger.error('Lighthouse::BenefitsIntake::SubmitCentralForm686cJob silent failure!', { e:, msg:, v2: })
        StatsD.increment("#{Lighthouse::BenefitsIntake::SubmitCentralForm686cJob::STATSD_KEY_PREFIX}}.silent_failure")
      end

      private

      def stamped_pdf_with_form(form_id, path, timestamp)
        PDFUtilities::DatestampPdf.new(path).run(
          text: 'Application Submitted on va.gov',
          x: %w[686C-674 686C-674-V2].include?(form_id) ? 400 : 300,
          y: %w[686C-674 686C-674-V2].include?(form_id) ? 675 : 775,
          text_only: true, # passing as text only because we override how the date is stamped in this instance
          timestamp:,
          page_number: %w[686C-674 686C-674-V2].include?(form_id) ? 6 : 0,
          template: "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
          multistamp: true
        )
      end

      def log_cmp_response(response)
        log_message_to_sentry("vre-central-mail-response: #{response}", :info, {}, { team: 'vfs-ebenefits' })
      end

      def valid_claim_data(saved_claim_id, vet_info)
        claim = SavedClaim::DependencyClaim.find(saved_claim_id)

        claim.add_veteran_info(vet_info)

        raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

        claim.formatted_686_data(vet_info)
      end

      def split_file_and_path(path)
        { file: path, file_name: path.split('/').last }
      end
    end
  end
end
