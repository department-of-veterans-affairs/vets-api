# frozen_string_literal: true

EVSSPolicy = Struct.new(:user, :evss) do
  include SentryLogging

  def access?
    if user.edipi.present? && user.ssn.present? && user.participant_id.present?
      true
    else
      log_message_to_sentry(
        'EVSS Pundit Policy bug',
        :info,
        {
          edipi_present: user.edipi.present?,
          ssn_present: user.ssn.present?,
          participant_id_present: user.participant_id.present?,
          user_loa: user&.loa,
          user: user.inspect
        },
        profile: 'pciu_profile'
      )

      false
    end
  end
end
