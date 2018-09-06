# frozen_string_literal: true

module CentralMail
  class SubmitForm4142Job
    include Sidekiq::Worker
    include SentryLogging

    FORM_ID = '21-4142'

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

    # Performs an asynchronous job for submitting a Form 4142 to central mail service
    #
    # @param user_uuid [String] The user's UUID that's associated with the form
    # @param form_content [Hash] The form content for 4142 and 4142A that is to be submitted
    # @param saved_claim [Array] The saved claim of 526 form to set receive date metadata using created_at
    # @param claim_id [String] Claim id received from EVSS 526 submission to generate unique PDF file path
    #
    def perform(user_uuid, form_content, saved_claim, claim_id)
      # find user using uuid
      user = User.find(user_uuid)

      # assign 526 saved claim
      @claim = saved_claim

      transaction_class.start(user, jid) if transaction_class.find_transaction(jid).blank?

      @pdf_path = process_record(form_content, claim_id)

      response = CentralMail::Service.new.upload(create_request_body)

      File.delete(@pdf_path)

      transaction_class.update_transaction(jid, :received, response.body)

      Rails.logger.info('Form4142 Submission',
                        'user_uuid' => user.uuid,
                        'job_id' => jid,
                        'job_status' => 'received')

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

    def process_record(form_content, claim_id)
      pdf_path = fill_ancillary_form(form_content, claim_id)
      stamped_path1 = CentralMail::DatestampPdf.new(pdf_path).run(text: 'VETS.GOV', x: 5, y: 5)
      CentralMail::DatestampPdf.new(stamped_path1).run(
        text: 'FDC Reviewed - Vets.gov Submission',
        x: 429,
        y: 770,
        text_only: true
      )
    end

    def fill_ancillary_form(form_data, claim_id)
      form_class = PdfFill::Forms::Va214142

      folder = 'tmp/pdfs'
      FileUtils.mkdir_p(folder)
      file_path = "#{folder}/#{FORM_ID}_#{claim_id}.pdf"

      hash_converter = PdfFill::HashConverter.new(form_class.date_strftime)

      new_hash = hash_converter.transform_data(
        form_data: form_class.new(form_data).merge_fields,
        pdftk_keys: form_class::KEY
      )

      PdfFill::Filler::PDF_FORMS.fill_form(
        "lib/pdf_fill/forms/pdfs/#{FORM_ID}.pdf",
        file_path,
        new_hash,
        flatten: false
      )

      PdfFill::Filler.combine_extras(file_path, hash_converter.extras_generator)

      file_path
    end

    def get_hash_and_pages(file_path)
      {
        hash: Digest::SHA256.file(file_path).hexdigest,
        pages: PDF::Reader.new(file_path).pages.size
      }
    end

    def generate_metadata
      form_pdf_metadata = get_hash_and_pages(@pdf_path)
      number_attachments = 0
      veteran_full_name = form_content['veteranFullName']
      address = form_content['claimantAddress'] || form_content['veteranAddress']
      receive_date = @claim.created_at.in_time_zone('Central Time (US & Canada)')

      metadata = {
        'veteranFirstName' => veteran_full_name['first'],
        'veteranLastName' => veteran_full_name['last'],
        'fileNumber' => form_content['vaFileNumber'] || form_content['veteranSocialSecurityNumber'],
        'receiveDt' => receive_date.strftime('%Y-%m-%d %H:%M:%S'),
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
