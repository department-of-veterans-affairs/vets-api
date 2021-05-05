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

      return empty_response(diaries) if diaries[:diaries].blank?

      standard_response(diaries)
    rescue => e
      report_error(e)
    end

    def update_diaries
      diaries = read_diaries[:diaries]
      updated_diaries = updated_diaries(diaries)

      option_hash = {
        award_type: 'CPL',
        beneficiary_id: @user.participant_id,
        participant_id: @user.participant_id
      }

      @service.diaries.update_diaries(option_hash, updated_diaries)
    end

    private

    def updated_diaries(diaries)
      diaries.map do |diary|
        if diary[:diary_reason_type] == '24' && diary[:diary_lc_status_type] == 'PEND'
          diary.merge!(diary_due_date: (Time.current + 1.year).iso8601)
        end

        diary
      end
    end

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
