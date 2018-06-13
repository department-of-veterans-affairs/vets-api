# frozen_string_literal: true

EVSSPolicy = Struct.new(:user, :evss) do
  include SentryLogging

  def rule_evaluations
    {
      :access => Dry::Validation.Schema do
        required(:edipi).filled
        required(:participant_id).filled
        required(:ssn).filled
      end.(edipi: user.edipi, participant_id: user.participant_id, ssn: user.ssn)
    }
  end

  def access?
    if rule_evaluations[:access].success?
      StatsD.increment('api.evss.policy.success') if user.loa3?

      true
    else
      if user.loa3?
        StatsD.increment('api.evss.policy.failure')

        log_message_to_sentry(
          'EVSS Pundit failure log',
          :info,
          {
            edipi_present: user.edipi.present?,
            ssn_present: user.ssn.present?,
            participant_id_present: user.participant_id.present?,
            user_loa: user&.loa
          },
          profile: 'pciu_profile'
        )
      end

      false
    end
  end
end
