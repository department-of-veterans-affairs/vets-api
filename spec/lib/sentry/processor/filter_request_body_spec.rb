# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sentry::Processor::FilterRequestBody do
  let(:client) { double('client') }
  let(:processor) { Sentry::Processor::FilterRequestBody.new(client) }
  let(:result) { processor.process(data) }

  let(:data) do
    {
      "tags"=>{"controller_name"=>"ppiu", "sign_in_method"=>{"service_name"=>"idme", "acct_type"=>nil}},
      "request"=>
       {
        "data"=>
         "{\n  \"account_type\": \"Checking\",\n  \"financial_institution_name\": \"Bank of Ad Hoc\",\n  \"account_number\": \"12345678\",\n  \"financial_institution_routing_number\": \"021000021\"\n}\n"
        }
      }
  end

  context 'with data from ppiu' do
    it 'should filter the request body' do
      expect(result['request']['data']).to eq(Sentry::Processor::PIISanitizer::FILTER_MASK)
    end
  end

  context 'with data from another controller' do
    before do
      data['tags']['controller_name'] = 'health_care_applications'
    end

    it 'shouldnt filter the request body' do
      expect(result['request']['data']).to_not eq(Sentry::Processor::PIISanitizer::FILTER_MASK)
    end
  end
end
