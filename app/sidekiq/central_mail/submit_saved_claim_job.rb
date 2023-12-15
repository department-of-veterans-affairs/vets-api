# frozen_string_literal: true

require 'central_mail/service'
require 'central_mail/datestamp_pdf'
require 'pension_burial/tag_sentry'
require 'pdf_info'

module CentralMail
  class SubmitSavedClaimJob
    include Sidekiq::Job
    include SentryLogging

    FOREIGN_POSTALCODE = '00000'
    STATSD_KEY_PREFIX = 'worker.central_mail.submit_saved_claim_job'

    # Sidekiq has built in exponential back-off functionality for retries
    # A max retry attempt of 14 will result in a run time of ~25 hours
    RETRY = 14

    sidekiq_options retry: RETRY

    class CentralMailResponseError < StandardError
    end

    sidekiq_retries_exhausted do |msg, _ex|
      Rails.logger.send(
        :error,
        "Failed all retries on CentralMail::SubmitSavedClaimJob, last error: #{msg['error_message']}"
      )
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
    end

    # Performs an asynchronous job for submitting a saved claim to central mail service
    #
    # @param saved_claim_id [Integer] the claim id
    #
    def perform(saved_claim_id)
      PensionBurial::TagSentry.tag_sentry
      @saved_claim_id = saved_claim_id
      log_message_to_sentry('Attempting CentralMail::SubmitSavedClaimJob', :info, generate_sentry_details)

      response = send_claim_to_central_mail(saved_claim_id)
      log_cmp_response(response) if @claim.is_a?(SavedClaim::VeteranReadinessEmploymentClaim)

      if response.success?
        update_submission('success')
        log_message_to_sentry('CentralMail::SubmitSavedClaimJob succeeded', :info, generate_sentry_details)

        @claim.send_confirmation_email if @claim.respond_to?(:send_confirmation_email)
      else
        raise CentralMailResponseError, response.to_s
      end
    rescue => e
      update_submission('failed')
      log_message_to_sentry(
        'CentralMail::SubmitSavedClaimJob failed, retrying...', :warn, generate_sentry_details(e)
      )
      raise
    end

    def send_claim_to_central_mail(saved_claim_id)
      @claim = SavedClaim.find(saved_claim_id)
      @pdf_path = process_record(@claim)

      @attachment_paths = @claim.persistent_attachments.map do |record|
        process_record(record)
      end

      response = CentralMail::Service.new.upload(create_request_body)

      File.delete(@pdf_path)
      @attachment_paths.each { |p| File.delete(p) }

      response
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
      veteran_full_name = form['veteranFullName']
      address = form['claimantAddress'] || form['veteranAddress']
      receive_date = @claim.created_at.in_time_zone('Central Time (US & Canada)')

      metadata = {
        'veteranFirstName' => remove_invalid_characters(veteran_full_name['first']),
        'veteranLastName' => remove_invalid_characters(veteran_full_name['last']),
        'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
        'receiveDt' => receive_date.strftime('%Y-%m-%d %H:%M:%S'),
        'uuid' => @claim.guid,
        'zipCode' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
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

    private

    def log_cmp_response(response)
      log_message_to_sentry("vre-central-mail-response: #{response}", :info, {}, { team: 'vfs-ebenefits' })
    end

    def generate_sentry_details(e = nil)
      details = {
        'guid' => @claim&.guid,
        'docType' => @claim&.form_id,
        'savedClaimId' => @saved_claim_id
      }
      details['error'] = e if e

      details
    end

    def remove_invalid_characters(str)
      # Replace characters that do not match the pattern with an empty string
      @claim.respond_to?(:central_mail_submission) ? str.gsub(%r{[^A-Za-z'/ -]}, '') : str
    end
  end
end
