# frozen_string_literal: true

module Form1010cg
  class DeliverAttachmentsToCARMAJob
    class MissingClaimException < StandardError; end

    include Sidekiq::Worker

    def perform(claim_guid)
      # Generate the PDF attachment
      # Get the POA attachment [If uploaded]
      # Build the CARMA attachments model
      # Submit to CARMA
    end

    private

    def claim
      @claim ||= SavedClaim::CaregiversAssistanceClaim.includes(:submission).find_by(guid: claim.guid)
    end

    def submission
      claim.submission
    end

    def poa_attachment
      @poa_attachment ||= Form1010cg::Attachment.find_by(guid: claim.parsed_form['poaAttachmentId'])
    end
  end
end
