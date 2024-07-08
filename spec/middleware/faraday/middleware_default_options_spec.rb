# frozen_string_literal: true

require 'rails_helper'

describe Faraday::Middleware do
  before do
    @stubs = Faraday::Adapter::Test::Stubs.new
    @stubs.get('/imminent-failure') do
      [500, {}, '']
    end
  end

  context 'include_request: false (default)' do
    it 'raises an error that does not include the request in the response body' do
      conn = Faraday.new do |c|
        c.adapter :test, @stubs
        c.response :raise_error
      end

      expect { conn.get('/imminent-failure') }
        .to raise_error do |error|
          expect(error.response[:request]).to be_nil
        end
    end
  end

  context 'include_request: true' do
    it 'raises an error that includes the request in the response body' do
      conn = Faraday.new do |c|
        c.adapter :test, @stubs
        c.response :raise_error, include_request: true
      end

      expect { conn.get('/imminent-failure') }
        .to raise_error do |error|
          expect(error.response[:request]).not_to be_nil
        end
    end
  end
end
