# frozen_string_literal: true

require 'rails_helper'
require 'sentry/scrubbers/filter_request_body'

RSpec.describe Sentry::Scrubbers::FilterRequestBody do
  context 'with PII in the [:request][:data] hash' do
    before do
      @scrubber = Sentry::Scrubbers::FilterRequestBody.new
    end

    it 'filters PII for a controller found in FILTERED_CONTROLLER' do
      sentry_request = create_sentry_request_with_pii(controller: 'ppiu')
      result = @scrubber.process(sentry_request)

      expect(result['request']['data']).to eql(Sentry::Scrubbers::PIISanitizer::FILTER_MASK)
    end

    it 'does not filter PII for a contoller not included in FILTERED_CONTROLLER' do
      sentry_request = create_sentry_request_with_pii(controller: 'another_controller')

      result = @scrubber.process(sentry_request)

      expect(result['request']['data']).not_to eql(Sentry::Scrubbers::PIISanitizer::FILTER_MASK)
      expect(result['request']['data']).to eql("{\n  \"account_type\": \"Checking\"}")
    end

    it 'works when there is no request body' do
      sentry_request =
        {
          'tags' => {
            'controller_name' => 'ppiu',
            'sign_in_method' => { 'service_name' => SignIn::Constants::Auth::IDME, 'acct_type' => nil }
          },
          'request' => {}
        }
      result = @scrubber.process(sentry_request)

      expect(result['request']['data']).to be_nil
    end
  end

  private

  def create_sentry_request_with_pii(controller: 'default')
    {
      'tags' => {
        'controller_name' => controller,
        'sign_in_method' => { 'service_name' => SignIn::Constants::Auth::IDME, 'acct_type' => nil }
      },
      'request' => {
        'data' => "{\n  \"account_type\": \"Checking\"}"
      }
    }
  end
end
