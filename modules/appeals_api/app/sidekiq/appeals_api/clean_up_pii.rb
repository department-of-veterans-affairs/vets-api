# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class CleanUpPii
    include Sidekiq::Job
    # Only retry for ~8 hours since the job is run daily
    sidekiq_options retry: 11, unique_for: 8.hours

    def perform
      AppealsApi::RemovePii.new(form_type: HigherLevelReview).run!
      AppealsApi::RemovePii.new(form_type: SupplementalClaim).run!
      AppealsApi::RemovePii.new(form_type: NoticeOfDisagreement).run!
    end
  end
end
