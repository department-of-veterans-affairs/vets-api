# frozen_string_literal: true

class GIController < ApplicationController
  skip_before_action :authenticate

  private

  def client(rest_call, scrubbed_params)
    @client ||= Gi.for_controller(rest_call, scrubbed_params)
  end

  def gi_response_body(rest_call, scrubbed_params)
    client(rest_call, scrubbed_params).body
  end

  def scrubbed_params
    params.except(:action, :controller, :format)
  end
end
