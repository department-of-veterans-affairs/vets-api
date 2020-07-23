# frozen_string_literal: true

module VBMS
  class Form686cPdfJob
    include Sidekiq::Worker
    # Generates PDF for 686c form and uploads to VBMS

    def perform(saved_claim_id)
      #
    end
  end
end
