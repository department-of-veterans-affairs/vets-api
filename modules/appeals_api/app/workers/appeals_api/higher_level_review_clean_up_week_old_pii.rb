# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class HigherLevelReviewCleanUpWeekOldPii
    include Sidekiq::Worker

    def perform
      AppealsApi::RemovePii.new(form_type: HigherLevelReview).run!
    end
  end
end
