# frozen_string_literal: true
require 'mhv_ac/account_creation_error'

module MHVControllerConcerns
  extend ActiveSupport::Concern

  included do
    before_action :authorize
    before_action :authenticate_client
  end

  protected

  def authorize
    raise_access_denied unless eligible_for_account_creation?
    raise_requires_terms_acceptance unless terms_and_conditions_accepted?
    raise_something_went_wrong unless authorized?
  end

  def raise_requires_terms_acceptance
    raise Common::Exceptions::Forbidden, detail: 'You have not accepted the terms of service'
  end

  def raise_something_went_wrong
    raise MHVAC::AccountCreationError
  end

  def authorized?
    current_user.mhv_account.accessible?
  end

  def eligible_for_account_creation?
    current_user.mhv_account.eligible?
  end

  def terms_and_conditions_accepted?
    current_user.mhv_account.terms_and_conditions_accepted?
  end

  def authenticate_client
    MHVLoggingService.login(current_user)
    client.authenticate if client.session.expired?
  end
end
