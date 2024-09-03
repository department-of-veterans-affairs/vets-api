# frozen_string_literal: true

LighthousePolicy = Struct.new(:user, :lighthouse) do
  def access?
    user.icn.present? && user.participant_id.present?
  end

  def direct_deposit_access?
    user.loa3? &&
      allowed_providers.include?(user.identity.sign_in[:service_name]) &&
      user.icn.present? && user.participant_id.present?
  end

  def itf_access?
    # Need to check for first name as Lighthouse will check for it
    # and throw an error if it's nil
    user.participant_id.present? && user.ssn.present? && user.last_name.present? && user.first_name
  end

  def access_update?
    user.loa3? &&
      allowed_providers.include?(user.identity.sign_in[:service_name]) &&
      user.icn.present? && user.participant_id.present?
  end

  alias_method :mobile_access?, :access_update?
  alias_method :rating_info_access?, :access?

  private

  def allowed_providers
    %w[
      idme
      oauth_IDME
      logingov
      oauth_LOGINGOV
    ].freeze
  end
end
