# frozen_string_literal: true

module CentralMail
  class SubmitForm4142Job
    include Sidekiq::Worker
    include SentryLogging

    FORM_ID = '21-4142'

    FOREIGN_POSTALCODE = '00000'

    # Sidekiq has built in exponential back-off functionality for retry's
    # A max retry attempt of 13 will result in a run time of ~25 hours
    RETRY = 13

    sidekiq_options retry: RETRY

    class CentralMailResponseError < Common::Exceptions::BackendServiceException
    end

    # This callback cannot be tested due to the limitations of `Sidekiq::Testing.fake!`
    sidekiq_retries_exhausted do |msg, _ex|
      transaction_class.update_transaction(jid, :exhausted)
      log_message_to_sentry(
        "Failed all retries on Form4142 submit, last error: #{msg['error_message']}",
        :error
      )
    end

    # Performs an asynchronous job for submitting a Form 4142 to central mail service
    #
    # @param user_uuid [String] The user's UUID that's associated with the form
    # @param form_content [Hash] The form content for 4142 and 4142A that is to be submitted
    # @param claim_id [String] Claim id received from EVSS 526 submission to generate unique PDF file path
    # @param saved_claim_created_at [DateTime] Claim receive date time for 526 form
    #
    def perform(user_uuid, form_content, claim_id, saved_claim_created_at)
      # find user using uuid
      user = User.find(user_uuid)

      transaction_class.start(user, jid) if transaction_class.find_transaction(jid).blank?

      format_saved_claim_created_at(saved_claim_created_at)

      @parsed_form = process_form(form_content)

      # process record to create PDF
      @pdf_path = process_record(@parsed_form, claim_id)

      response = CentralMail::Service.new.upload(create_request_body)

      transaction_class.update_transaction(jid, :received, response.body)

      Rails.logger.info('Form4142 Submission',
                        'user_uuid' => user.uuid,
                        'job_id' => jid,
                        'job_status' => 'received')

      handle_service_exception(response) if response.present? && response.status.between?(201, 600)
    rescue CentralMailResponseError => e
      raise(e)
    rescue Common::Exceptions::GatewayTimeout => e
      handle_gateway_timeout_exception(e)
    rescue StandardError => e
      handle_standard_error(e)
    ensure
      # Delete the temporary PDF file
      File.delete(@pdf_path) if @pdf_path.present?
    end

    def create_request_body
      body = {
        'metadata' => generate_metadata.to_json
      }

      body['document'] = to_faraday_upload(@pdf_path)

      body
    end

    def to_faraday_upload(file_path)
      Faraday::UploadIO.new(
        file_path,
        Mime[:pdf].to_s
      )
    end

    def process_record(form_content, claim_id)
      pdf_path = PdfFill::Filler.fill_ancillary_form(form_content, claim_id, FORM_ID)
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
      form = @parsed_form
      form_pdf_metadata = get_hash_and_pages(@pdf_path)
      number_attachments = 0
      veteran_full_name = form['veteranFullName']
      address = form['claimantAddress'] || form['veteranAddress']

      metadata = {
        'veteranFirstName' => veteran_full_name['first'],
        'veteranLastName' => veteran_full_name['last'],
        'fileNumber' => form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
        'receiveDt' => @saved_claim_created_at.strftime('%Y-%m-%d %H:%M:%S'),
        'uuid' => jid,
        'zipCode' => address['country'] == 'USA' ? address['postalCode'] : FOREIGN_POSTALCODE,
        'source' => 'Vets.gov',
        'hashV' => form_pdf_metadata[:hash],
        'numberAttachments' => number_attachments,
        'docType' => FORM_ID,
        'numberPages' => form_pdf_metadata[:pages]
      }

      metadata
    end

    def format_saved_claim_created_at(saved_claim_created_at)
      @saved_claim_created_at = saved_claim_created_at
      if @saved_claim_created_at.blank?
        @saved_claim_created_at = Time.now.in_time_zone('Central Time (US & Canada)')
      else
        @saved_claim_created_at = Date.parse(@saved_claim_created_at) if @saved_claim_created_at.is_a?(String)
        @saved_claim_created_at = @saved_claim_created_at.in_time_zone('Central Time (US & Canada)')
      end
    end

    def process_form(form_content)
      form_content = form_content.to_json if form_content.is_a?(Hash)

      # Parse form content to JSON
      @parsed_form ||= JSON.parse(form_content)
    end

    def transaction_class
      AsyncTransaction::CentralMail::VA4142SubmitTransaction
    end

    def handle_service_exception(response)
      # create service error with CentralMailResponseError
      error = create_service_error(nil, self.class, response)
      if response.status.between?(500, 600)
        transaction_class.update_transaction(jid, :retrying, response.body)
        raise error
      else
        transaction_class.update_transaction(jid, :non_retryable_error, response.body)
        extra_content = { response: response.body, status: :non_retryable_error, jid: jid }
        Rails.logger.error('Error Message' => error.message)
        log_exception_to_sentry(error, extra_content)
      end
    end

    def handle_gateway_timeout_exception(error)
      transaction_class.update_transaction(jid, :retrying, error.message)
      raise error
    end

    def handle_standard_error(error)
      transaction_class.update_transaction(jid, :non_retryable_error, error.to_s)
      extra_content = { status: :non_retryable_error, jid: jid }
      log_exception_to_sentry(error, extra_content)
    end

    def create_service_error(key, source, response, _error = nil)
      response_values = response_values(key, source, response.status, response.body)
      CentralMailResponseError.new(key, response_values, nil, nil)
    end

    def response_values(key, source, status, detail)
      {
        status: status,
        detail: detail,
        code:   key,
        source: source.to_s
      }
    end
  end
end
