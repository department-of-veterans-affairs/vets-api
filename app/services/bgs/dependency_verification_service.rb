# frozen_string_literal: true

module BGS
  class DependencyVerificationService < BaseService
    def read_diaries
      diaries = @service.diaries.read_diaries(
        { participant_id: @user.participant_id, ssn: @user.ssn }
      )

      return empty_response(diaries) if diaries[:diaries].blank?

      standard_response(diaries)
    rescue => e
      report_error(e)
    end

    private

    def empty_response(diaries)
      {
        dependency_decs: [diaries.dig(:dependency_decs, :dependency_dec)],
        diaries: []
      }
    end

    def standard_response(diaries)
      {
        dependency_decs: diaries.dig(:dependency_decs, :dependency_dec),
        diaries: diaries.dig(:diaries, :diary)
      }
    end
  end
end
