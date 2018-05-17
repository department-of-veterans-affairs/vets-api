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
          user_loa: user&.loa
        },
        profile: 'pciu_profile'
      )

      raise Common::Exceptions::Forbidden.new(detail: "User does not have access to the requested resource due to missing values: #{missing_values}", source: 'EVSS')
    end
  end

  # Returns a comma-separated string of the user's blank attributes. `participant_id` is AKA `corp_id`.
  #
  # @return [String] Comma-separated string of the attribute names
  #
  def missing_values
    missing = []

    missing << 'corp_id' if user.participant_id.blank?
    missing << 'edipi' if user.edipi.blank?
    missing << 'ssn' if user.ssn.blank?

    missing.join(', ')
  end
end
