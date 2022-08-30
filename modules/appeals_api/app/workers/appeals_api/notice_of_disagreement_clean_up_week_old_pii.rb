# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class NoticeOfDisagreementCleanUpWeekOldPii
    include Sidekiq::Worker

    def perform
      return unless enabled?

      AppealsApi::RemovePii.new(form_type: NoticeOfDisagreement).run!
    end

    private

    def enabled?
      Flipper.enabled?(:decision_review_nod_pii_expunge_enabled)
    end
  end
end
