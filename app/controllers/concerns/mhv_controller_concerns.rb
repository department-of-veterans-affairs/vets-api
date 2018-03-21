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
    # The user must (1) have an account that is either existing or
    # created and upgraded by us or (2) be eligible to have an
    # account created and upgraded by us.
    raise_access_denied unless accessible_or_eligible_for_creation?

    # Stop if the user needs to accept terms and conditions.
    raise_requires_terms_acceptance if current_user.mhv_account.needs_terms_acceptance?

    # Stop if further actions are necessary to access MHV services.
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

  def accessible_or_eligible_for_creation?
    current_user.mhv_account.accessible? || current_user.mhv_account.eligible?
  end

  def authenticate_client
    MHVLoggingService.login(current_user)
    client.authenticate if client.session.expired?
  end
end
