# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe 'Filter Parameter Logging', type: :request do
  before(:context)  { Rails.application.routes.draw { post '/test_params' => 'test_params#create' } }
  after(:context)   { Rails.application.reload_routes! }

  around do |example|
    @log_output = StringIO.new
    appender   = SemanticLogger.add_appender(io: @log_output, formatter: :json, level: :debug)

    ac_logger        = ActionController::Base.logger
    original_ac_lvl  = ac_logger.level
    ac_logger.level  = :debug

    example.run
  ensure
    SemanticLogger.flush
    ac_logger.level = original_ac_lvl
    SemanticLogger.remove_appender(appender)
  end

  def log_messages
    SemanticLogger.flush
    @log_output
      .string
      .each_line
      .filter_map { |l| JSON.parse(l)['message'] rescue nil }
      .join("\n")
  end

  it 'filters uploaded file parameters but logs HTTP upload object' do
    file = fixture_file_upload(
      Rails.root.join('spec/fixtures/files/test_file_with_pii.txt'),
      'text/plain'
    )

    post '/test_params', params: { attachment: file }

    expect(log_messages).to include('"attachment"')
    expect(log_messages).not_to include('test_file_with_pii.txt')
    expect(log_messages).to     include('@original_filename="[FILTERED!]"')
    expect(log_messages).to     include('@headers="[FILTERED!]"')
  end

  it 'filters file parameters when represented as a hash' do
    file_params = {
      'content_type'      => 'application/pdf',
      'file'              => 'sensitive binary content',
      'original_filename' => 'private_file.docx',
      'headers'           => 'Content-Disposition: form-data; name="attachment"; filename="private_file.docx"',
      'tempfile'          => '#<Tempfile:/tmp/RackMultipart20241231-96-nixrw6.pdf (closed)>',
      'metadata'          => { 'extra' => 'should_be_filtered' }
    }

    post '/test_params', params: { attachment: file_params }

    expect(log_messages).not_to include('private_file.docx')
    expect(log_messages).not_to include('sensitive binary content')
    expect(log_messages).to     include('"file"=>"[FILTERED]"')
    expect(log_messages).to     include('"original_filename"=>"[FILTERED]"')
    expect(log_messages).to     include('"metadata"=>{"extra"=>"[FILTERED]"}')
  end

  it 'filters SSN from logs' do
    post '/test_params', params: { name: 'John Doe', ssn: '123-45-6789', email: 'johndoe@example.com' }

    expect(log_messages).not_to include('123-45-6789')
    expect(log_messages).to     include('"ssn"=>"[FILTERED]"')
  end
end

class TestParamsController < ActionController::API
  def create
    render json: { status: 'ok' }, status: :ok
  end
end
