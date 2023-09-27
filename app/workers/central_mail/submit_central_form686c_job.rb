# frozen_string_literal: true

require 'central_mail/service'
require 'central_mail/datestamp_pdf'
require 'pdf_info'

module CentralMail
  class SubmitCentralForm686cJob
    include Sidekiq::Worker
    include SentryLogging

    FOREIGN_POSTALCODE = '00000'
    FORM_ID = '686C-674'

    sidekiq_options retry: false

    class CentralMailResponseError < StandardError; end

    def extract_uuid_from_central_mail_message(data)
      data.body[/(?<=\[).*?(?=\])/].split(': ').last if data.body.present?
    end

    def perform(saved_claim_id, encrypted_vet_info, encrypted_user_struct)
      vet_info = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      user_struct = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user_struct))
      # if the 686c-674 has failed we want to call this central mail job (credit to submit_saved_claim_job.rb)
      # have to re-find the claim and add the relevant veteran info
      Rails.logger.info('CentralMail::SubmitCentralForm686cJob running!',
                        { user_uuid: user_struct['uuid'], saved_claim_id:, icn: user_struct['icn'] })
      @claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      @claim.add_veteran_info(vet_info)

      # process the main pdf record and the attachments as we would for a vbms submission
      @pdf_path = process_record(@claim)

      @attachment_paths = @claim.persistent_attachments.map do |record|
        process_record(record)
      end

      # upload with the request body (adapted from submit_saved_claim_job.rb)
      response = CentralMail::Service.new.upload(create_request_body)
      File.delete(@pdf_path)
      @attachment_paths.each { |p| File.delete(p) }

      check_success(response, saved_claim_id, user_struct)
    rescue => e
      # if we fail, update the associated central mail record to failed and send the user the failure email
      Rails.logger.warn('CentralMail::SubmitCentralForm686cJob failed!',
                        { user_uuid: user_struct['uuid'], saved_claim_id:, icn: user_struct['icn'], error: e.message })
      update_submission('failed')
      DependentsApplicationFailureMailer.build(OpenStruct.new(user_struct)).deliver_now if user_struct['email'].present?
      raise
    end

    def check_success(response, saved_claim_id, user_struct)
      if response.success?
        # if a success, update the associated central mail submission record to success and send confirmation
        Rails.logger.info('CentralMail::SubmitCentralForm686cJob succeeded!',
                          { user_uuid: user_struct['uuid'], saved_claim_id:, icn: user_struct['icn'],
                            centralmail_uuid: extract_uuid_from_central_mail_message(response) })
        update_submission('success')
        send_confirmation_email(OpenStruct.new(user_struct))
      else
        raise CentralMailResponseError
      end
    end

    def create_request_body
      body = {
        'metadata' => generate_metadata.to_json
      }

      body['document'] = to_faraday_upload(@pdf_path)
      @attachment_paths.each_with_index do |file_path, i|
        j = i + 1
        body["attachment#{j}"] = to_faraday_upload(file_path)
      end

      body
    end

    def update_submission(state)
      @claim.central_mail_submission.update!(state:) if @claim.respond_to?(:central_mail_submission)
    end

    def to_faraday_upload(file_path)
      Faraday::UploadIO.new(
        file_path,
        Mime[:pdf].to_s
      )
    end

    def process_record(record)
      pdf_path = record.to_pdf
      stamped_path1 = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VA.GOV', x: 5, y: 5)
      CentralMail::DatestampPdf.new(stamped_path1).run(
        text: 'FDC Reviewed - va.gov Submission',
        x: 429,
        y: 770,
        text_only: true
      )
    end

    def get_hash_and_pages(file_path)
      {
        hash: Digest::SHA256.file(file_path).hexdigest,
        pages: PdfInfo::Metadata.read(file_path).pages
      }
    end

    # rubocop:disable Metrics/MethodLength
    def generate_metadata
      form = @claim.parsed_form
      form_pdf_metadata = get_hash_and_pages(@pdf_path)
      number_attachments = @attachment_paths.size
      veteran_full_name = form['veteran_information']['full_name']
      address = form['dependents_application']['veteran_contact_information']['veteran_address']
      receive_date = @claim.created_at.in_time_zone('Central Time (US & Canada)')

      metadata = {
        'veteranFirstName' => veteran_full_name['first'],
        'veteranLastName' => veteran_full_name['last'],
        'fileNumber' => form['veteran_information']['file_number'] || form['veteran_information']['ssn'],
        'receiveDt' => receive_date.strftime('%Y-%m-%d %H:%M:%S'),
        'uuid' => @claim.guid,
        'zipCode' => address['country_name'] == 'USA' ? address['zip_code'] : FOREIGN_POSTALCODE,
        'source' => 'va.gov',
        'hashV' => form_pdf_metadata[:hash],
        'numberAttachments' => number_attachments,
        'docType' => @claim.form_id,
        'numberPages' => form_pdf_metadata[:pages]
      }

      @attachment_paths.each_with_index do |file_path, i|
        j = i + 1
        attachment_pdf_metadata = get_hash_and_pages(file_path)
        metadata["ahash#{j}"] = attachment_pdf_metadata[:hash]
        metadata["numberPages#{j}"] = attachment_pdf_metadata[:pages]
      end

      metadata
    end
    # rubocop:enable Metrics/MethodLength

    def send_confirmation_email(user)
      return if user.va_profile_email.blank?

      VANotify::ConfirmationEmail.send(
        email_address: user.va_profile_email,
        template_id: Settings.vanotify.services.va_gov.template_id.form686c_confirmation_email,
        first_name: user&.first_name&.upcase,
        user_uuid_and_form_id: "#{user.uuid}_#{FORM_ID}"
      )
    end

    private

    def log_cmp_response(response)
      log_message_to_sentry("vre-central-mail-response: #{response}", :info, {}, { team: 'vfs-ebenefits' })
    end

    def valid_claim_data(saved_claim_id, vet_info)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)

      claim.add_veteran_info(vet_info)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      claim.formatted_686_data(vet_info)
    end
  end
end
