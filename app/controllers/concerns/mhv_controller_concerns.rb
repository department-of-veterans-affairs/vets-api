# frozen_string_literal: true

require 'beta_switch'

module MHVControllerConcerns
  extend ActiveSupport::Concern
  include BetaSwitch

  included do
    before_action :authorize
    before_action :authenticate_client
  end

  protected

  def authorize
    if beta_enabled?(current_user.uuid, 'health_account')
      authorize_beta
    else
      (current_user&.loa3? && current_user&.mhv_correlation_id.present?) || raise_access_denied
    end
  end

  def authorize_beta
    raise_access_denied if current_user.mhv_account.ineligible?
    raise_requires_terms_acceptance if current_user.mhv_account.needs_terms_acceptance?
    begin
      current_user.mhv_account.create_and_upgrade! unless current_user.mhv_account.upgraded?
    # TODO: rescue more specifically if mhv_account raises more specifically
    ensure
      raise_something_went_wrong unless current_user.mhv_account.upgraded?
    end
  end

  def raise_requires_terms_acceptance
    raise Common::Exceptions::Forbidden, detail: 'You have not accepted the terms of service'
  end

  def raise_something_went_wrong
    # TODO: Change this to something other than a BackendServiceException
    raise Common::Exceptions::BackendServiceException, 'MHVAC1'
  end

  def authenticate_client
    MHVLoggingService.login(current_user)
    client.authenticate if client.session.expired?
  end
end
