# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sentry::Processor::FilterRequestBody do
  context 'with clearer specs' do
    before(:each) do
      client = double('client')
      @processor = Sentry::Processor::FilterRequestBody.new(client)
    end

    it 'filters PII found in a FILTERED_CONTROLLER' do
      sentry_request = create_sentry_request(controller: 'ppiu')
      result = @processor.process(sentry_request)

      expect(result['request']['data']).to eql(Sentry::Processor::PIISanitizer::FILTER_MASK)
    end

    it 'ignores any contoller not specified in FILTERED_CONTROLLER' do
      sentry_request = create_sentry_request(controller: 'another_controller')

      result = @processor.process(sentry_request)

      expect(result['request']['data']).not_to eql(Sentry::Processor::PIISanitizer::FILTER_MASK)
      expect(result['request']['data']).to eql("{\n  \"account_type\": \"Checking\"}")
    end

    it 'works when there is no request body' do
      sentry_request =
        {
          'tags' => { 'controller_name' => 'ppiu', 'sign_in_method' => { 'service_name' => 'idme', 'acct_type' => nil } },
          'request' => {}
        }
      result = @processor.process(sentry_request)

      expect(result['request']['data']).to eql(nil)
    end
  end

  private

  def create_sentry_request(controller: 'default')
    pii_content = {
      'data' => "{\n  \"account_type\": \"Checking\"}"
    }.freeze

    sentry_request =
      {
        'tags' => { 'controller_name' => controller, 'sign_in_method' => { 'service_name' => 'idme', 'acct_type' => nil } },
        'request' => pii_content
      }
    end
end
