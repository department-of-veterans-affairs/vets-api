# frozen_string_literal: true

module BGS
  class DependencyVerificationService < BaseService
    def read_diaries
      diaries = @service.diaries.read_diaries(
        {
          beneficiary_id: @user.participant_id,
          participant_id: @user.participant_id,
          ssn: @user.ssn,
          award_type: 'CPL'
        }
      )
      dependency_decisions = diaries[:dependency_decs][:dependency_dec]
      diaries[:dependency_decs][:dependency_dec] = normalize_dependency_decisions(dependency_decisions)

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

    def normalize_dependency_decisions(dependency_decisions)
      dependency_decisions.delete_if do |dependency_decision|
        !dependency_decision.has_key?(:award_effective_date) ||
        dependency_decision[:award_effective_date].future?
        # || dependency_decision[:dependency_status_type] == 'NAWDDEP'
      end
    end
  end
end
