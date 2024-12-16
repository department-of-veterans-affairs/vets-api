# frozen_string_literal: true

require 'pension_burial/tag_sentry'
require 'lgy/tag_sentry'

module V0
  class ClaimDocumentsController < ApplicationController
    service_tag 'claims-shared'
    skip_before_action(:authenticate)

    def create
      Rails.logger.info "Creating PersistentAttachment FormID=#{form_id}"

      attachment = klass.new(form_id:)
      # add the file after so that we have a form_id and guid for the uploader to use
      attachment.file = unlock_file(params['file'], params['password'])

      raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

      attachment.save

      Rails.logger.info "Success creating PersistentAttachment FormID=#{form_id} AttachmentID=#{attachment.id}"

      render json: PersistentAttachmentSerializer.new(attachment)
    rescue => e
      Rails.logger.error "Error creating PersistentAttachment FormID=#{form_id} AttachmentID=#{attachment.id} #{e}"
      raise e
    end

    private

    def klass
      case form_id
      when '21P-527EZ', '21P-530', '21P-530V2'
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
      return file unless File.extname(file) == '.pdf' && file_password

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
  end
end
