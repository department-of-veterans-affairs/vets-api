# frozen_string_literal: true

require 'pension_burial/tag_sentry'
require 'lgy/tag_sentry'
require 'claim_documents/monitor'
require 'lighthouse/benefits_intake/service'
require 'pdf_utilities/datestamp_pdf'

module V0
  class ClaimDocumentsController < ApplicationController
    service_tag 'claims-shared'
    skip_before_action(:authenticate)
    before_action :load_user

    def create
      uploads_monitor.track_document_upload_attempt(form_id, current_user)

      @attachment = klass&.new(form_id:)
      # add the file after so that we have a form_id and guid for the uploader to use
      @attachment.file = unlock_file(params['file'], params['password'])

      if Flipper.enabled?(:document_upload_validation_enabled) && !stamped_pdf_valid? &&
         %w[21P-527EZ 21P-530 21P-530V2].include?(form_id)
        raise Common::Exceptions::ValidationErrors, @attachment
      end

      raise Common::Exceptions::ValidationErrors, @attachment unless @attachment.valid?

      @attachment.save

      uploads_monitor.track_document_upload_success(form_id, @attachment.id, current_user)

      render json: PersistentAttachmentSerializer.new(@attachment)
    rescue => e
      uploads_monitor.track_document_upload_failed(form_id, @attachment&.id, current_user, e)
      raise e
    end

    private

    def klass
      case form_id
      when '21P-527EZ', '21P-530EZ', '21P-530V2'
        PensionBurial::TagSentry.tag_sentry
        PersistentAttachments::PensionBurial
      when '21-686C', '686C-674'
        PersistentAttachments::DependencyClaim
      when '26-1880'
        LGY::TagSentry.tag_sentry
        PersistentAttachments::LgyClaim
      end
    end

    def form_id
      params[:form_id].upcase
    end

    def unlock_file(file, file_password)
      return file unless File.extname(file) == '.pdf' && file_password.present?

      pdftk = PdfForms.new(Settings.binaries.pdftk)
      tmpf = Tempfile.new(['decrypted_form_attachment', '.pdf'])

      begin
        pdftk.call_pdftk(file.tempfile.path, 'input_pw', file_password, 'output', tmpf.path)
      rescue PdfForms::PdftkError => e
        file_regex = %r{/(?:\w+/)*[\w-]+\.pdf\b}
        password_regex = /(input_pw).*?(output)/
        sanitized_message = e.message.gsub(file_regex, '[FILTERED FILENAME]').gsub(password_regex, '\1 [FILTERED] \2')
        log_message_to_sentry(sanitized_message, 'warn')
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: I18n.t('errors.messages.uploads.pdf.incorrect_password'),
          source: 'PersistentAttachment.unlock_file'
        )
      end

      file.tempfile.unlink
      file.tempfile = tmpf
      file
    end

    def stamped_pdf_valid?
      extension = File.extname(@attachment&.file&.id)
      allowed_types = PersistentAttachment::ALLOWED_DOCUMENT_TYPES
      unless allowed_types.include?(extension)
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: I18n.t('errors.messages.extension_allowlist_error', extension:, allowed_types:),
          source: 'PersistentAttachment.unlock_file'
        )
      end

      document = PDFUtilities::DatestampPdf.new(@attachment.to_pdf).run(text: 'VA.GOV', x: 5, y: 5)
      intake_service.valid_document?(document:)
    rescue BenefitsIntake::Service::InvalidDocumentError => e
      @attachment.errors.add(:attachment, e.message)
      false
    rescue PdfForms::PdftkError
      @attachment.errors.add(:attachment, 'File is corrupt and cannot be uploaded')
      false
    end

    def intake_service
      @intake_service ||= BenefitsIntake::Service.new
    end

    def uploads_monitor
      @uploads_monitor ||= ClaimDocuments::Monitor.new('claim_documents_controller')
    end
  end
end
