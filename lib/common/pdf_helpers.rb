# frozen_string_literal: true

require 'hexapdf'
require 'vets/shared_logging'

module Common
  module PdfHelpers
    extend Vets::SharedLogging

    def self.unlock_pdf(input_file, password, output_file)
      doc = HexaPDF::Document.open(input_file, decryption_opts: { password: })
      doc.encrypt(name: nil)
      doc.write(output_file)
    rescue HexaPDF::EncryptionError => e
      log_message_to_sentry(e.message, 'warn')
      raise Common::Exceptions::UnprocessableEntity.new(
        detail: I18n.t('errors.messages.uploads.pdf.incorrect_password'),
        source: 'Common::PdfHelpers.unlock_pdf'
      )
    rescue HexaPDF::Error => e
      log_message_to_sentry(e.message, 'warn')
      raise Common::Exceptions::UnprocessableEntity.new(
        detail: I18n.t('errors.messages.uploads.pdf.invalid'),
        source: 'Common::PdfHelpers.unlock_pdf'
      )
    end
  end
end
