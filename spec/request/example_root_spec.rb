# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Root path', type: :request do
  it 'Provides a welcome message at root' do
    get '/'
    assert_response :success
  end

  it 'Provides a welcome message at root even with unsafe host' do
    host! 'unsafe.com'
    get '/'
    assert_response :success
  end
end
