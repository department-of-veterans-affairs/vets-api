# frozen_string_literal: true

class GenerateClaimPDFJob
  include Sidekiq::Worker

  sidekiq_options queue: 'tasker'

  def perform(saved_claim_id)
    claim = SavedClaim.find(saved_claim_id)
    file = claim.to_pdf
    return false unless file
    db_file = claim.class::PERSISTENT_CLASS.new(form_id: claim.form_id, saved_claim: claim).tap do |pf|
      # the file depends on form_id being set, which is why it's set here rather than in the initializer
      pf.file = file
    end
    db_file.save!
    db_file.reload.process
  ensure
    File.delete(file) if file
  end
end
