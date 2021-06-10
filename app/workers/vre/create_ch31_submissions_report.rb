# frozen_string_literal: true

module VRE
  class CreateCh31SubmissionsReport
    require 'csv'
    include Sidekiq::Worker

    def updated_at_range
      (@time - 24.hours)..(@time - 1.second)
    end

    def get_claims_submitted_in_range
      SavedClaim::VeteranReadinessEmploymentClaim.where(
        updated_at: updated_at_range
      )
    end

    def perform
      @time = Time.zone.now
      submitted_claims = get_claims_submitted_in_range

      Ch31SubmissionsReportMailer.build(submitted_claims).deliver_now
    end
  end
end
