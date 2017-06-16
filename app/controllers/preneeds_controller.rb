# frozen_string_literal: true
require 'preneeds/service'

class PreneedsController < ApplicationController
  protected

  def client
    @client ||= Preneeds::Service.new
  end
end
