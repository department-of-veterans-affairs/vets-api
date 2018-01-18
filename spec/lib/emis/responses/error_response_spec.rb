# frozen_string_literal: true

require 'rails_helper'
require 'emis/responses/error_response'

describe EMIS::Responses::ErrorResponse do
  it 'gives me its exception' do
    exception = ArgumentError.new('blat')
    r = EMIS::Responses::ErrorResponse.new(exception)
    expect(r.error).to eq(exception)
  end
end
