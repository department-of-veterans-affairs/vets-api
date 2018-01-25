# frozen_string_literal: true

class EVSSController < ApplicationController
  before_action :authorize_user

  protected

  def authorize_user
    unless current_user.can_access_evss?
      raise Common::Exceptions::Forbidden, detail: 'User not authorized to access EVSS based services'
    end
  end
end
