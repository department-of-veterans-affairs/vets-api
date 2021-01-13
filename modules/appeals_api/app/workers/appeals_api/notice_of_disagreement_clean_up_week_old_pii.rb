# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class NoticeOfDisagreementCleanUpWeekOldPii
    include Sidekiq::Worker

    def perform
      AppealsApi::RemovePii.new(form_type: NoticeOfDisagreement).run!
    end
  end
end
