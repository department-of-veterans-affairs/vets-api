# frozen_string_literal: true
require 'burials/service'

class BurialsController < ApplicationController
  protected

  def client
    @client ||= Burials::Service.new
  end
end
