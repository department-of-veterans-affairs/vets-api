# frozen_string_literal: true

require 'preneeds/service'

class PreneedsController < ApplicationController
  skip_before_action(:authenticate)

  protected

  def client
    @client ||= Preneeds::Service.new
  end
end
