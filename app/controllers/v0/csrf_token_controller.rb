# frozen_string_literal: true

class V0::CsrfTokenController < ApplicationController
  service_tag 'csrf-token'

  skip_before_action :authenticate

  def index; end
end
