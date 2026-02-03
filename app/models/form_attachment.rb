# frozen_string_literal: true

class FormAttachment < ApplicationRecord
  include SetGuid

  has_kms_key
  has_encrypted :file_data, key: :kms_key, **lockbox_options

  validates(:file_data, :guid, presence: true)

  before_destroy { |record| record.get_file.delete }

  def set_file_data!(file, file_password = nil)
    attachment_uploader = get_attachment_uploader
    file = unlock_pdf(file, file_password) if File.extname(file).downcase == '.pdf' && file_password.present?
    attachment_uploader.store!(file)
    self.file_data = { filename: attachment_uploader.filename }.to_json
  rescue CarrierWave::IntegrityError => e
    Rails.logger.warn("FormAttachment.set_file_data error: #{e.message}")
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
    pdftk = PdfForms.new(Settings.binaries.pdftk)
    tmpf = Tempfile.new(['decrypted_form_attachment', '.pdf'])

    begin
      pdftk.call_pdftk(file.tempfile.path, 'input_pw', file_password, 'output', tmpf.path)
    rescue PdfForms::PdftkError => e
      file_regex = %r{/(?:\w+/)*[\w-]+\.pdf\b}i
      password_regex = /(input_pw).*?(output)/
      sanitized_message = e.message.gsub(file_regex, '[FILTERED FILENAME]').gsub(password_regex, '\1 [FILTERED] \2')
      Rails.logger.warn("FormAttachment.unlock_pdf error: #{sanitized_message}")
      raise Common::Exceptions::UnprocessableEntity.new(
        detail: I18n.t('errors.messages.uploads.pdf.incorrect_password'),
        source: 'FormAttachment.unlock_pdf'
      ), cause: nil
    end

    file.tempfile.unlink
    file.tempfile = tmpf
    file
  end

  def get_attachment_uploader
    @au ||= self.class::ATTACHMENT_UPLOADER_CLASS.new(guid)
  end
end
