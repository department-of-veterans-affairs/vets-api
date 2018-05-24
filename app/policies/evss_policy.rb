# frozen_string_literal: true

EVSSPolicy = Struct.new(:user, :evss) do
  include SentryLogging

  def access?
    if user.edipi.present? && user.ssn.present? && user.participant_id.present?
      log_message_to_sentry('EVSS Pundit success log', :info) if user.loa3?

      true
    else
      if user.loa3?
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
