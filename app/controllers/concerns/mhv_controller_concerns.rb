# frozen_string_literal: true
module MHVControllerConcerns
  extend ActiveSupport::Concern

  included do
    before_action :authorize
    before_action :authenticate_client
  end

  def authorize
    current_user&.can_access_mhv?(@session) || raise_access_denied
  end

  def authenticate_client
    MHVLoggingService.login(current_user)
    client.authenticate if client.session.expired?
  end
end
