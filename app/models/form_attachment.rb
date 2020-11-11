# frozen_string_literal: true

class FormAttachment < ApplicationRecord
  include SetGuid
  include SentryLogging

  attr_encrypted(:file_data, key: Settings.db_encryption_key)

  validates(:file_data, :guid, presence: true)

  before_destroy { |record| record.get_file.delete }

  def set_file_data!(file, file_password = nil)
    attachment_uploader = get_attachment_uploader
    file = unlock_pdf(file, file_password) if file_password.present?
    attachment_uploader.store!(file)
    self.file_data = { filename: attachment_uploader.filename }.to_json
  rescue CarrierWave::IntegrityError => e
    log_exception_to_sentry(e, nil, nil, 'warn')
    raise Common::Exceptions::UnprocessableEntity.new(detail: e.message, source: 'FormAttachment.set_file_data')
  end

  def parsed_file_data
    @parsed_file_data ||= JSON.parse(file_data)
  end

  def get_file
    attachment_uploader = get_attachment_uploader
    attachment_uploader.retrieve_from_store!(
      parsed_file_data['filename']
    )
    attachment_uploader.file
  end

  private

  def unlock_pdf(file, file_password)
    return file unless File.extname(file) == '.pdf'

    pdftk = PdfForms.new(Settings.binaries.pdftk)
    tmpf = Tempfile.new(['decrypted_form_attachment', '.pdf'])

    error_messages = pdftk.call_pdftk(file.tempfile.path, 'input_pw', file_password, 'output', tmpf.path)
    if error_messages.present?
      log_message_to_sentry(error_messages, 'warn')
      raise Common::Exceptions::UnprocessableEntity.new(
        detail: I18n.t('errors.messages.uploads.pdf.incorrect_password'),
        source: 'FormAttachment.unlock_pdf'
      )
    end
    file.tempfile.unlink
    file.tempfile = tmpf
    file
  end

  def get_attachment_uploader
    self.class::ATTACHMENT_UPLOADER_CLASS.new(guid)
  end
end
