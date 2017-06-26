# frozen_string_literal: true
class SavedClaim::Burial < SavedClaim
  FORM = '21P-530'
  CONFIRMATION = 'PEN'
  PERSISTENT_CLASS = PersistentAttachment::PensionBurial
  ATTACHMENT_KEYS = [:transportationReceipts, :deathCertificate].freeze

  def regional_office
    PensionBurial::ProcessingOffice.address_for(open_struct_form.claimantAddress.postalCode)
  end

  def to_pdf
    #     # return FormToPDF::Blahblah.convert(open_struct_form)
    #     claim_t = Tempfile.new([guid, '.txt'])
    #     claim_t.write(form)
    #     claim_t.flush
    #     out_dir = Rails.root.join('tmp', 'pdfs', confirmation_number)
    #     FileUtils.mkdir_p(out_dir)
    #     pdf_temp_file = File.join(out_dir, "#{FORM}.pdf")
    #     `fold -w 80 -s #{claim_t.path} | convert -page A4 -font Courier -pointsize 10 text:- #{pdf_temp_file}`
    #     return File.open(pdf_temp_file)
    #   ensure
    #     File.delete(claim_t)
  end

  def attachment_keys
    self.class::ATTACHMENT_KEYS
  end
end
