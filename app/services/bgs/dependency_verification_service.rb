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

    def normalize_dependency_decisions(diaries)
      diaries[:dependency_decs][:dependency_dec].delete_if do |dep_dec|
        !dep_dec.has_key?(:award_effective_date)
      end
    end
  end
end
