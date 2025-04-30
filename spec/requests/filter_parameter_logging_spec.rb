# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe 'Filter Parameter Logging', type: :request do
  let(:logger) { SemanticLogger::Test::CaptureLogEvents.new }

  before do
    Rails.application.routes.draw do
      post '/test_params', to: 'test_params#create'
    end

    allow(TestParamsController).to receive(:logger).and_return(logger)
  end

  after do
    Rails.application.reload_routes!
  end

  it 'filters uploaded file parameters but logs HTTP upload object' do
    file = fixture_file_upload(
      Rails.root.join('spec', 'fixtures', 'files', 'test_file_with_pii.txt'), 'text/plain'
    )

    post '/test_params', params: { attachment: file }
    logs = logger.events.to_json

    puts "DEBUG LOG OUTPUT TEST 1: #{logs}"

    expect(logs).to include('"attachment"')

    expect(logs).not_to include('test_file_with_pii.txt')
    expect(logs).not_to include('John Doe')
    expect(logs).not_to include('123-45-6789')
    expect(logs).not_to include('johndoe@example.com')

    expect(logs).to include('"original_filename":"[FILTERED!]"')
    expect(logs).to include('"headers":"[FILTERED!]"')
  end

  it 'filters file parameters when represented as a hash' do
    file_params = {
      'content_type' => 'application/pdf',
      'file' => 'sensitive binary content',
      'original_filename' => 'private_file.docx',
      'headers' => 'Content-Disposition: form-data; name="attachment"; filename="private_file.docx"',
      # NOTE: tempfile and content_type are explicitly allowed to pass unfiltered:
      'tempfile' => '#<Tempfile:/tmp/RackMultipart20241231-96-nixrw6.pdf (closed)>',
      'metadata' => { 'extra' => 'should_be_filtered' } # Nested hash
    }

    post '/test_params', params: { attachment: file_params }
    logs = logger.events.to_json

    puts "DEBUG LOG OUTPUT TEST 2: #{logs}"

    expect(logs).not_to include('private_file.docx')
    expect(logs).not_to include('sensitive binary content')

    expect(logs).to include('"file":"[FILTERED]"')
    expect(logs).to include('"original_filename":"[FILTERED]"')
    expect(logs).to include('"headers":"[FILTERED]"')
    expect(logs).to include('"metadata":{"extra":"[FILTERED]"}')

    expect(logs).to include('"attachment"')
  end

  it 'filters SSN from logs' do
    sensitive_params = {
      name: 'John Doe',
      ssn: '123-45-6789',
      email: 'johndoe@example.com'
    }

    post '/test_params', params: sensitive_params
    logs = logger.events.to_json

    puts "DEBUG LOG OUTPUT 3: #{logs}" # Debugging output

    expect(logs).not_to include('123-45-6789') # SSN should be wiped out
    expect(logs).not_to include('johndoe@example.com') # Ensure emails are also wiped
    expect(logs).to include('"ssn":"[FILTERED]"') # Confirm it's being replaced
  end
end

class TestParamsController < ActionController::API
  def create
    render json: { status: 'ok' }, status: :ok
  end
end
