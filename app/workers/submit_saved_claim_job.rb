# frozen_string_literal: true

class SubmitSavedClaimJob
  include Sidekiq::Worker

  def perform(saved_claim_id)
    claim = SavedClaim.find(saved_claim_id)
    pdf_path = claim.to_pdf
    stamped_path = PensionBurial::DatestampPdf.new(pdf_path).run(text: 'VETS.GOV', x: 5, y: 5)
    binding.pry; fail
  end
end
