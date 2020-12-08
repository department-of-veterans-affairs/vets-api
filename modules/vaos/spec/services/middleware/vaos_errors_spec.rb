# frozen_string_literal: true

require 'rails_helper'
require 'vaos_backend_service_exception'

class MyEnv
  attr_reader :status, :body, :url, :success

  def initialize(status, body, url, success)
    @status = status
    @body = body
    @url = url
    @success = success
  end

  def success?
    @success
  end
end

describe VAOS::Middleware::Response::Errors do
  error = {
    'message' => 'message'
  }
  errors = {
    'errors' => [
      {
        'errorMessage' => 'first'
      },
      {
        'errorMessage' => 'second'
      }
    ]
  }

  let(:success) { MyEnv.new(400, 'body', 'url', true) }
  let(:env_400) { MyEnv.new(400, 'body', 'url', false) }
  let(:env_403) { MyEnv.new(403, 'body', 'url', false) }
  let(:env_404) { MyEnv.new(404, 'body', 'url', false) }
  let(:env_409) { MyEnv.new(409, 'body', 'url', false) }
  let(:env_500) { MyEnv.new(500, 'body', 'url', false) }
  let(:env_other) { MyEnv.new(401, 'body', 'url', false) }
  let(:env_with_error) { MyEnv.new(400, JSON[error], 'url', false) }
  let(:env_with_errors) { MyEnv.new(400, JSON[errors], 'url', false) }

  describe 'on complete' do
    context 'with success' do
      it 'passes' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(success) }.not_to raise_error
      end
    end

    context 'with 400 errors' do
      it 'raises a VAOS_400 BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_400) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_400')
          expect(e.response_values[:detail]).to equal('body')
          expect(e.response_values[:source][:vamf_url]).to equal('url')
          expect(e.response_values[:source][:vamf_body]).to equal('body')
          expect(e.response_values[:source][:vamf_status]).to equal(400)
        }
      end
    end

    context 'with a 403 error' do
      it 'raises VAOS_403 BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_403) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_403')
          expect(e.response_values[:detail]).to equal('body')
          expect(e.response_values[:source][:vamf_url]).to equal('url')
          expect(e.response_values[:source][:vamf_body]).to equal('body')
          expect(e.response_values[:source][:vamf_status]).to equal(403)
        }
      end
    end

    context 'with a 404 error' do
      it 'raises VAOS_404 BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_404) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_404')
          expect(e.response_values[:detail]).to equal('body')
          expect(e.response_values[:source][:vamf_url]).to equal('url')
          expect(e.response_values[:source][:vamf_body]).to equal('body')
          expect(e.response_values[:source][:vamf_status]).to equal(404)
        }
      end
    end

    context 'with 409 errors' do
      it 'raises a VAOS_409A BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_409) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_409A')
          expect(e.response_values[:detail]).to equal('body')
          expect(e.response_values[:source][:vamf_url]).to equal('url')
          expect(e.response_values[:source][:vamf_body]).to equal('body')
          expect(e.response_values[:source][:vamf_status]).to equal(409)
        }
      end
    end

    context 'with a 500..510 error' do
      it 'raises VAOS_502 error' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_500) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_502')
          expect(e.response_values[:detail]).to equal('body')
          expect(e.response_values[:source][:vamf_url]).to equal('url')
          expect(e.response_values[:source][:vamf_body]).to equal('body')
          expect(e.response_values[:source][:vamf_status]).to equal(500)
        }
      end
    end

    context 'with all other errors' do
      it 'raises a VA900 error' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_other) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VA900')
          expect(e.response_values[:detail]).to equal('body')
          expect(e.response_values[:source][:vamf_url]).to equal('url')
          expect(e.response_values[:source][:vamf_body]).to equal('body')
          expect(e.response_values[:source][:vamf_status]).to equal(401)
        }
      end
    end

    context 'with error' do
      it 'parses error message' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_with_error) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_400')
          expect(e.response_values[:detail]).to match('message')
        }
      end
    end

    context 'with errors' do
      it 'parses error message' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_with_errors) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_400')
          expect(e.response_values[:detail]).to match('first')
          expect(e.response_values[:detail]).not_to match('second')
        }
      end
    end
  end
end
