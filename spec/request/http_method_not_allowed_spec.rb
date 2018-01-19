# frozen_string_literal: true

require 'rails_helper'
require 'http_method_not_allowed'

class MockRackApp
  def initialize
    @request_headers = {}
  end

  def call(_env)
    [200, { 'Content-Type' => 'text/plain' }, ['OK']]
  end
end

RSpec.describe HttpMethodNotAllowed, type: :request do
  let(:app) { MockRackApp.new }
  subject { described_class.new(app) }
  let(:r) { Rack::MockRequest.new(subject) }

  it 'responds with 200 for allowed method' do
    get '/'
    expect(response).to have_http_status(:ok)
  end

  it 'responds with 405 with unsupported method' do
    response = r.request(:foo, '/')
    expect(response.status).to equal(405)
  end
end
