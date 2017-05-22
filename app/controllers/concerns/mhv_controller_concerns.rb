# frozen_string_literal: true
module MHVControllerConcerns
  extend ActiveSupport::Concern

  included do
    before_action :authorize
    before_action :authenticate_client
  end

  def authorize
    # TODO: somwhere in here we would instead want to use MHVAccount to create, upgrade, or return error.
    # alternately, maybe this would be tied in to the user .can_access_mhv method.
    # Also this needs to be environment specific, such that it does what we currently do for staging and production,
    # but the new stuff for dev and local maybe (based on feature toggle.)
    current_user&.can_access_mhv? || raise_access_denied
  end

  def authenticate_client
    MHVLoggingService.login(current_user)
    client.authenticate if client.session.expired?
  end
end
