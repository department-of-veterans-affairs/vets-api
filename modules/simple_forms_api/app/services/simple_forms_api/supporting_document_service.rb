# frozen_string_literal: true
module SimpleFormsApi
  class SupportingDocumentService
    include SentryLogging

    attr_reader :params, :uploaded_file, :form_id

    def initialize(params)
      @params = params
      @uploaded_file = params['file']
      @form_id = params['form_id']
    end

    def process_upload
      attachment = create_initial_attachment

      if needs_pdf_conversion?(attachment)
        converted_pdf_path = convert_attachment_to_pdf(attachment)
        update_attachment_with_pdf(attachment, converted_pdf_path)
      end

      validation_result = validate_pdf_document(attachment)
      return validation_result unless validation_result.success?

      success_result(attachment)
    rescue BenefitsIntakeService::Service::InvalidDocumentError => e
      handle_document_validation_error(e)
    rescue => e
      Rails.logger.error('Simple forms api - error processing supporting document', error: e)
      error_result('An error occurred while processing your document. Please try again.', :internal_server_error)
    end

    private

    def create_initial_attachment
      attachment = PersistentAttachments::MilitaryRecords.new(form_id:)
      attachment.file = uploaded_file

      raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

      attachment.save
      attachment
    end

    def needs_pdf_conversion?(attachment)
      attachment.file.content_type != 'application/pdf'
    end

    def convert_attachment_to_pdf(attachment)
      Rails.logger.info('Simple forms api - converting file to PDF',
                        { original_filename: attachment.original_filename,
                          content_type: attachment.file.content_type })

      pdf_path = attachment.to_pdf
      raise IOError, 'PDF conversion failed - output file not created' unless File.exist?(pdf_path)

      pdf_path
    end

    def update_attachment_with_pdf(attachment, pdf_path)
      File.open(pdf_path, 'rb')
      uploaded_pdf = ActionDispatch::Http::UploadedFile.new(
        tempfile: create_tempfile_from_pdf(pdf_path),
        filename: "#{File.basename(attachment.original_filename, '.*')}.pdf",
        type: 'application/pdf'
      )

      attachment.file = uploaded_pdf
      attachment.save

      FileUtils.rm_f(pdf_path)
    end

    def create_tempfile_from_pdf(pdf_path)
      tempfile = Tempfile.new(['converted', '.pdf'])
      FileUtils.cp(pdf_path, tempfile.path)
      tempfile
    end

    def validate_pdf_document(attachment)
      return success_result unless should_validate_document?(attachment)

      # Create a temporary file path for validation
      temp_path = attachment.file.tempfile.path

      service = BenefitsIntakeService::Service.new
      service.valid_document?(document: temp_path)
      success_result
    rescue BenefitsIntakeService::Service::InvalidDocumentError => e
      handle_document_validation_error(e)
    end

    def should_validate_document?(attachment)
      %w[40-0247 40-10007].include?(form_id) &&
        attachment.file.content_type == 'application/pdf'
    end

    def handle_document_validation_error(error)
      if form_id == '40-10007'
        detail_msg = "We weren't able to upload your file. Make sure the file is in an " \
                     'accepted format and size before continuing.'
        error_result([{ detail: detail_msg }], :unprocessable_entity)
      else
        error_result("Document validation failed: #{error.message}", :unprocessable_entity)
      end
    end

    # Result objects for clean interface
    def success_result(attachment = nil)
      ServiceResult.new(success: true, attachment:)
    end

    def error_result(errors, status = :unprocessable_entity)
      errors = [{ detail: errors }] if errors.is_a?(String)
      ServiceResult.new(success: false, errors:, status:)
    end
  end

  class ServiceResult
    attr_reader :attachment, :errors, :status

    def initialize(success:, attachment: nil, errors: nil, status: nil)
      @success = success
      @attachment = attachment
      @errors = errors
      @status = status
    end

    def success?
      @success
    end
  end
end
