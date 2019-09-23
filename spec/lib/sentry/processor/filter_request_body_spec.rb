# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sentry::Processor::FilterRequestBody do
  let(:client) { double('client') }
  let(:processor) { Sentry::Processor::FilterRequestBody.new(client) }
  let(:result) { processor.process(sentry_data) }

  let(:sentry_data) do
    {
      'tags' => { 'controller_name' => 'ppiu', 'sign_in_method' => { 'service_name' => 'idme', 'acct_type' => nil } },
      'request' =>
       {
         'data' =>
          "{\n  \"account_type\": \"Checking\"}"
       }
    }
  end

  def self.expect_filter(filtered)
    it "should#{filtered ? '' : "n't"} filter the request body" do
      expect(result['request']['data']).public_send(
        filtered ? 'to' : 'to_not',
        eq(Sentry::Processor::PIISanitizer::FILTER_MASK)
      )
    end
  end

  context 'with data from a controller in FILTERED_CONTROLLER' do
    expect_filter(true)
  end

  context 'with data from another controller' do
    before do
      sentry_data['tags']['controller_name'] = 'health_care_applications'
    end

    expect_filter(false)
  end

  context 'with no request body' do
    before do
      sentry_data['request'].delete('data')
    end

    expect_filter(false)
  end

  context 'with clearer specs' do
    it 'filters PII found in a FILTERED_CONTROLLER' do
      sentry_request =
        {
          'tags' => { 'controller_name' => 'ppiu', 'sign_in_method' => { 'service_name' => 'idme', 'acct_type' => nil } },
          'request' =>
           {
             'data' =>
              "{\n  \"account_type\": \"Checking\"}"
           }
        }
      client = double('client')
      processor = Sentry::Processor::FilterRequestBody.new(client)
      result = processor.process(sentry_request)

      expect(result['request']['data']).to eql(Sentry::Processor::PIISanitizer::FILTER_MASK)
    end

    it 'ignores any contoller not specified in FILTERED_CONTROLLER' do
      sentry_request =
        {
          'tags' => { 'controller_name' => 'another_controller', 'sign_in_method' => { 'service_name' => 'idme', 'acct_type' => nil } },
          'request' =>
           {
             'data' =>
              "{\n  \"account_type\": \"Checking\"}"
           }
        }
      client = double('client')
      processor = Sentry::Processor::FilterRequestBody.new(client)
      result = processor.process(sentry_request)

      expect(result['request']['data']).not_to eql(Sentry::Processor::PIISanitizer::FILTER_MASK)
      expect(result['request']['data']).to eql("{\n  \"account_type\": \"Checking\"}")
    end

    it 'works when there is no request body' do
      sentry_request =
        {
          'tags' => { 'controller_name' => 'ppiu', 'sign_in_method' => { 'service_name' => 'idme', 'acct_type' => nil } },
          'request' => {}
        }
      client = double('client')
      processor = Sentry::Processor::FilterRequestBody.new(client)
      result = processor.process(sentry_request)

      expect(result['request']['data']).to eql(nil)
    end
  end
end
