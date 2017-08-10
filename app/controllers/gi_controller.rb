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
      begin
        v.respond_to?(:encode) && v.encode!('UTF-8', 'binary')
      rescue StandardError
        raise Common::Exceptions::InvalidFieldValue.new('parameter', v.scrub)
      end
    end
  end
end
