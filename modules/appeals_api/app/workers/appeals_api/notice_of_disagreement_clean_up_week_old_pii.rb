# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class NoticeOfDisagreementCleanUpWeekOldPii
    include Sidekiq::Worker
    include SentryLogging

    def perform
      @updated_nods = NoticeOfDisagreement.ready_to_have_pii_expunged.remove_pii

      return if pii_was_removed? || no_notice_of_disagreements_are_ready_to_have_pii_expunged?

      log_message_to_sentry(
        'Failed to expunge PII from NoticeOfDisagreements (modules/appeals_api)',
        :error,
        ids: ids_of_notice_of_disagreements_ready_to_have_pii_expunged
      )
    end

    private

    def pii_was_removed?
      @updated_nods.present?
    end

    def no_notice_of_disagreements_are_ready_to_have_pii_expunged?
      ids_of_notice_of_disagreements_ready_to_have_pii_expunged.empty?
    end

    def ids_of_notice_of_disagreements_ready_to_have_pii_expunged
      @ids_of_notice_of_disagreements_ready_to_have_pii_expunged ||=
        NoticeOfDisagreement.ready_to_have_pii_expunged.pluck :id
    end
  end
end
