# frozen_string_literal: true

module CentralMail
  class SubmitForm4142Job
    include Sidekiq::Worker
    include SentryLogging

    FOREIGN_POSTALCODE = '00000'

    # Sidekiq has built in exponential back-off functionality for retrys
    # A max retry attempt of 10 will result in a run time of ~8 hours
    RETRY = 10

    sidekiq_options retry: RETRY

    # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
    sidekiq_retries_exhausted do |msg, _ex|
      transaction_class.update_transaction(jid, :exhausted)
      log_message_to_sentry(
        "Failed all retries on Form4142 submit, last error: #{msg['error_message']}",
        :error
      )
    end

    # Performs an asynchronous job for submitting a form4142 to central mail service
    #
    # @param user_uuid [String] The user's uuid thats associated with the form
    # @param form_content [Hash] The form content that is to be submitted
    # @param claim [Array] The saved claim that is to be submitted
    #
    def perform(user_uuid, _form_content, claim)
      user = User.find(user_uuid)

      @claim = claim

      transaction_class.start(user, jid) if transaction_class.find_transaction(jid).blank?

      # TODO: uncomment to integrate PDF generation
      # @pdf_path = process_record(@claim)

      response = CentralMail::Service.new.upload(create_request_body)

      # TODO: uncomment to integrate PDF generation
      # File.delete(@pdf_path)

      transaction_class.update_transaction(jid, :received, response.body)

      Rails.logger.info('Form4142 Submission',
                        'user_uuid' => user.uuid,
                        'job_id' => jid,
                        'job_status' => 'received')

      # Do a clean up of 4142 form from in progress
      CentralMail::SubmitForm4142Cleanup.perform_async(user_uuid)

      handle_service_exception(response) unless response.success?
    rescue Common::Exceptions::GatewayTimeout => e
      handle_gateway_timeout_exception(e)
    rescue StandardError => e
      # Treat unexpected errors as hard failures
      # This includes BackeEndService Errors (including 403's)
      transaction_class.update_transaction(jid, :non_retryable_error, e.to_s)
    end

    def create_request_body
      body = {
        # TODO: uncomment to integrate PDF generation
        # 'metadata' => generate_metadata.to_json
      }

      # TODO: uncomment to integrate PDF generation
      # body['document'] = to_faraday_upload(@pdf_path)

      body
    end

    def to_faraday_upload(file_path)
      Faraday::UploadIO.new(
        file_path,
        Mime[:pdf].to_s
      )
    end

    def process_record(record)
      pdf_path = record.to_pdf
      stamped_path1 = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VETS.GOV', x: 5, y: 5)
      CentralMail::DatestampPdf.new(stamped_path1).run(
        text: 'FDC Reviewed - Vets.gov Submission',
        x: 429,
        y: 770,
        text_only: true
      )
    end

    def get_hash_and_pages(file_path)
      {
        hash: Digest::SHA256.file(file_path).hexdigest,
        pages: PDF::Reader.new(file_path).pages.size
      }
    end

    def generate_metadata
      form = @claim.parsed_form
      form_pdf_metadata = get_hash_and_pages(@pdf_path)
      number_attachments = 0
      veteran_full_name = form['veteranFullName']
      address = form['claimantAddress'] || form['veteranAddress']
      receive_date = @claim.created_at.in_time_zone('Central Time (US & Canada)')

      metadata = {
        'veteranFirstName' => veteran_full_name['first'],
        'veteranLastName' => veteran_full_name['last'],
        'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
        'receiveDt' => receive_date.strftime('%Y-%m-%d %H:%M:%S'),
        'uuid' => jid,
        'zipCode' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
        'source' => 'Vets.gov',
        'hashV' => form_pdf_metadata[:hash],
        'numberAttachments' => number_attachments,
        'docType' => @claim.form_id,
        'numberPages' => form_pdf_metadata[:pages]
      }

      metadata
    end

    def transaction_class
      AsyncTransaction::CentralMail::VA4142SubmitTransaction
    end

    def handle_service_exception(response)
      if response.status.between?(500, 600)
        transaction_class.update_transaction(jid, :retrying, response.body)
        raise error
      end
      transaction_class.update_transaction(jid, :non_retryable_error, response.body)
      extra_content = { status: :non_retryable_error, jid: jid }
      log_exception_to_sentry(error, extra_content)
    end

    def handle_gateway_timeout_exception(error)
      transaction_class.update_transaction(jid, :retrying, error.message)
      raise error
    end
  end
end
