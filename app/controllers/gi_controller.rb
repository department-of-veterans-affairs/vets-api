# frozen_string_literal: true
require 'gi/client'

class GIController < ApplicationController
  skip_before_action :authenticate

  private

  def client
    @client ||= ::GI::Client.new
  end

  def scrubbed_params
    params.except(:action, :controller, :format).transform_values do |v|
      v.encode!('UTF-8', invalid: :replace, undef: :replace, replace: '')
    end
  end
end
