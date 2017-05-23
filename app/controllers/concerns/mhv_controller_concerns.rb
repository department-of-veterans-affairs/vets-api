# frozen_string_literal: true
module MHVControllerConcerns
  extend ActiveSupport::Concern

  included do
    before_action :authorize
    before_action :authenticate_client
  end

  protected

  def authorize
    raise_access_denied if mhv_account.ineligible?
    raise_requires_terms_acceptance if mhv_account.needs_terms_acceptance?
    mhv_account.create_and_upgrade! unless mhv_account.upgraded?
    raise_something_went_wrong unless mhv_account.upgraded?
  end

  def mhv_account
    @account ||= MhvAccount.find_or_initialize_by(user_uuid: current_user.uuid)
  end

  def raise_requires_terms_acceptance
    raise Common::Exceptions::Forbidden, detail: 'You have not accepted the terms of service.'
  end

  def raise_something_went_wrong
    # TODO: any additional data could probably be provided in source.
    raise Common::Exceptions::Forbidden, detail: 'Something went wrong. Please contact support.'
  end

  def authenticate_client
    MHVLoggingService.login(current_user)
    client.authenticate if client.session.expired?
  end
end
