# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Root path', type: :request do
  it 'Provides a welcome message at root' do
    get '/'
    assert_response :success
  end
end
