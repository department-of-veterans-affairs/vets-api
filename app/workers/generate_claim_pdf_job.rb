# frozen_string_literal: true
class GenerateClaimPDFJob
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: 'tasker'

  def perform(saved_claim_id)
    claim = SavedClaim.find(saved_claim_id)
    file = claim.to_pdf
    return false unless file
    claim.class::PERSISTENT_CLASS.new(form_id: claim.form_id, saved_claim: claim).tap do |pf|
      pf.file = file
      pf.process
    end.save
  ensure
    File.delete(file) if file
  end
end
