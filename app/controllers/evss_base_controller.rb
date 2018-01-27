# frozen_string_literal: true

class EVSSBaseController < ApplicationController
  before_action :authorize_user

  private

  def authorize_user
    authorize :evss, :access?
  end
end
