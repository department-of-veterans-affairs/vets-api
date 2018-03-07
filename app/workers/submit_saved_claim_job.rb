# frozen_string_literal: true

class SubmitSavedClaimJob
  include Sidekiq::Worker

  def perform(saved_claim_id)
    claim = SavedClaim.find(saved_claim_id)
    final_paths = (claim.persistent_attachments + [claim]).map do |record|
      pdf_path = record.to_pdf
      stamped_path1 = PensionBurial::DatestampPdf.new(pdf_path).run(text: 'VETS.GOV', x: 5, y: 5)
      PensionBurial::DatestampPdf.new(stamped_path1).run(
        text: 'FDC Reviewed - Vets.gov Submission',
        x: 429,
        y: 770,
        text_only: true
      )
    end
    binding.pry; fail
  end
end
