# frozen_string_literal: true
module MHVControllerConcerns
  extend ActiveSupport::Concern

  included do
    before_action :authorize
    before_action :authenticate_client
  end

  protected

  def authorize
    raise_access_denied if !current_user&.loa3? || current_user.mhv_account.ineligible?
    raise_requires_terms_acceptance if current_user.mhv_account.needs_terms_acceptance?
    create_mhv_account! unless current_user.mhv_account.upgraded?
  end

  def raise_requires_terms_acceptance
    raise Common::Exceptions::Forbidden, detail: 'You have not accepted the terms of service'
  end

  def raise_something_went_wrong(original_error = nil)
    exception_options = original_error.try(:service_response) || {}
    raise Common::Exceptions::BackendServiceException.new('MHVACCTCREATION900', exception_options)
  end

  def authenticate_client
    MHVLoggingService.login(current_user)
    client.authenticate if client.session.expired?
  end

  def create_mhv_account!
    current_user.mhv_account.create_and_upgrade!
    original_error = nil
  rescue Common::Exceptions::BackendServiceException => error
    original_error = error
  ensure
    raise_something_went_wrong(original_error) unless current_user.mhv_account.upgraded?
  end
end
