# frozen_string_literal: true

require 'health_beta'

module MHVControllerConcerns
  extend ActiveSupport::Concern
  include HealthBeta

  included do
    before_action :authorize
    before_action :authenticate_client
  end

  protected

  def authorize
    if beta_enabled?(current_user.uuid)
     raise_access_denied if current_user.mhv_account.ineligible?
      raise_requires_terms_acceptance if current_user.mhv_account.needs_terms_acceptance?
      current_user.mhv_account.create_and_upgrade! unless current_user.mhv_account.upgraded?
      raise_something_went_wrong unless current_user.mhv_account.upgraded?
    else
      (current_user&.loa3? && current_user&.mhv_correlation_id.present?) || raise_access_denied
    end
  end

  def raise_requires_terms_acceptance
    raise Common::Exceptions::Forbidden, detail: 'You have not accepted the terms of service'
  end

  def raise_something_went_wrong
    # TODO: any additional data could probably be provided in source.
    raise Common::Exceptions::Forbidden, detail: 'Something went wrong. Please contact support'
  end

  def authenticate_client
    MHVLoggingService.login(current_user)
    client.authenticate if client.session.expired?
  end
end
