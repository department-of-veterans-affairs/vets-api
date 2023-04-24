# frozen_string_literal: true

require 'appeals_api/decision_review_report'

module AppealsApi
  class WeeklyErrorReportMailer < ApplicationMailer
    def build(recipients:, friendly_duration: '')
      @friendly_duration = friendly_duration
      @friendly_env = (Settings.vsp_environment || Rails.env).titleize

      body = stuck_err_hlrs + stuck_err_nods + stuck_err_scs
      return if body.empty?

      body = ['AppealType, Guid, Source, Status, CreatedAt, UpdatedAt'] + body

      mail(
        to: recipients,
        subject: "#{@friendly_duration} Error Decision Review API report (#{@friendly_env})",
        content_type: 'text/html',
        body: body.join('<br>')
      )
    end

    private

    def stuck_err_hlrs
      stuck_hlr_statuses = HigherLevelReview::STATUSES - HigherLevelReview::COMPLETE_STATUSES - ['error']
      err_hlrs   = HigherLevelReview.v2_or_v0.where(status: 'error')
      stuck_hlrs = HigherLevelReview.v2_or_v0.where(status: stuck_hlr_statuses)
                                    .where('updated_at < ?', 1.week.ago.beginning_of_day)
      err_hlrs.or(stuck_hlrs).order(:created_at).map { |hlr| "HLR, #{build_line(hlr)}" }
    end

    def stuck_err_nods
      stuck_nod_statuses = NoticeOfDisagreement::STATUSES - NoticeOfDisagreement::COMPLETE_STATUSES - ['error']
      err_nods   = NoticeOfDisagreement.where(status: 'error')
      stuck_nods = NoticeOfDisagreement.where(status: stuck_nod_statuses)
                                       .where('updated_at < ?', 1.month.ago.beginning_of_day)
      err_nods.or(stuck_nods).order(:created_at).map { |nod| "NOD, #{build_line(nod)}" }
    end

    def stuck_err_scs
      stuck_sc_statuses = SupplementalClaim::STATUSES - SupplementalClaim::COMPLETE_STATUSES - ['error']
      err_scs   = SupplementalClaim.where(status: 'error')
      stuck_scs = SupplementalClaim.where(status: stuck_sc_statuses)
                                   .where('updated_at < ?', 1.week.ago.beginning_of_day)
      err_scs.or(stuck_scs).order(:created_at).map { |sc| "SC, #{build_line(sc)}" }
    end

    def build_line(appeal)
      "#{appeal.id}, #{appeal.source}, #{appeal.status}, #{appeal.created_at}, #{appeal.updated_at}"
    end
  end
end
