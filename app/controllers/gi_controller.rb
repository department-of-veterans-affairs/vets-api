# frozen_string_literal: true

require 'gi/client'

class GIController < ApplicationController
  skip_before_action :authenticate

  private

  def client
    @client ||= ::GI::Client.new
  end

  def scrubbed_params
    params.except(:action, :controller, :format)
  end

  def safe_encoded_params(input)
    input.transform_values do |v|
      begin
        v.respond_to?(:encode) && v.encode!('UTF-8', 'binary')
      rescue EncodingError
        raise Common::Exceptions::InvalidFieldValue.new('parameter', v.scrub)
      end
    end
  end
end
