require 'rails_helper'
require 'stringio'

# TODO: Fix this test as it doesn't seem to work
# Right now I'm jus testing by running
#
#    RAILS_ENABLE_TEST_LOG=true RAILS_ENV=test NOCOVERAGE=true bundle exec rspec spec/requests/filter_parameter_logging_spec.rb
# And then tailing log/test.log.
RSpec.describe 'Filter Parameter Logging', type: :request do
  before do
    # Capture logs in memory instead of the default Rails logger
    @original_logger = Rails.logger
    @log_output = StringIO.new
    #Rails.logger = ActiveSupport::Logger.new(@log_output)

    # Define a test endpoint inline (if you don't have one already)
    # This creates a dummy route and controller action for testing
    Rails.application.routes.draw do
      post '/test_params' => 'test_params#create'
    end

    class TestParamsController < ActionController::API
      def create
        # Just respond with something
        render json: { status: 'ok' }, status: :ok
      end
    end
  end

  after do
    Rails.logger = @original_logger
    # Reload the routes after the test to avoid affecting other specs
    Rails.application.reload_routes!
  end

  it 'filters sensitive string parameters' do
    post '/test_params', params: { sensitive_key: 'secret_value', category: 'public_info' }
    logs = @log_output.string

    # Allowed param should remain as is
    expect(logs).to include('"category"=>"public_info"')
    # Sensitive param should be filtered
    expect(logs).not_to include('secret_value')
    expect(logs).to include('"sensitive_key"=>"FILTERED"')
  end

  it 'filters numeric parameters' do
    post '/test_params', params: { sensitive_number: 12345 }
    logs = @log_output.string

    expect(logs).not_to include('12345')
    expect(logs).to include('"sensitive_number"=>"FILTERED"')
  end

  it 'filters uploaded file parameters' do
    file = fixture_file_upload('test_file_with_pii.txt', 'text/plain')
    post '/test_params', params: { upload: file }
    logs = @log_output.string

    # filename should be filtered
    expect(logs).not_to include('test_file_with_pii.txt')
    expect(logs).to include('original_filename="FILTERED"')
  end
end
