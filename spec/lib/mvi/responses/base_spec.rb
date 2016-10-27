# frozen_string_literal: true
require 'rails_helper'
require 'mvi/responses/find_candidate'
require "#{Rails.root}/spec/support/mvi/mvi_response"

describe MVI::Responses::Base do
  let(:klass) do
    Class.new(MVI::Responses::Base) do
      mvi_endpoint :PRPA_IN201305UV02
    end
  end
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:body) { File.read('spec/support/mvi/find_candidate_response.xml') }

  describe '#intialize' do
    it 'should be initialized with the correct attrs' do
      allow(faraday_response).to receive(:body) { body }
      response = klass.new(faraday_response)

      expect(response.code).to eq('AA')
      expect(response.query).to eq('foo')
      expect(response.original_response).to eq('<xml><some_tags/></xml>')
    end
  end

  describe '#body' do
    it 'should invoke the subclass body' do
      allow(faraday_response).to receive(:body) { body }
      allow(faraday_response).to receive(:xml) { xml }
      response = klass.new(faraday_response)

      expect { response.body }.to raise_error(MVI::Responses::NotImplementedError)
    end
  end
end
