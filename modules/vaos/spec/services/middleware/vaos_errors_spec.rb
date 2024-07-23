# frozen_string_literal: true

require 'rails_helper'

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

  let(:url) { URI.parse('url') }
  let(:url_w_icn) { URI.parse('https://veteran.apps.va.gov/id/1234567890V123456') }
  let(:success) { Faraday::Env.new(:get, nil, url, nil, nil, nil, nil, nil, nil, nil, 200, nil, 'response_body') }
  let(:env_400) { Faraday::Env.new(:get, nil, url, nil, nil, nil, nil, nil, nil, nil, 400, nil, 'response_body') }
  let(:env_403) { Faraday::Env.new(:get, nil, url, nil, nil, nil, nil, nil, nil, nil, 403, nil, 'response_body') }
  let(:env_404) { Faraday::Env.new(:get, nil, url, nil, nil, nil, nil, nil, nil, nil, 404, nil, 'response_body') }
  let(:env_409) { Faraday::Env.new(:get, nil, url, nil, nil, nil, nil, nil, nil, nil, 409, nil, 'response_body') }
  let(:env_500) { Faraday::Env.new(:get, nil, url, nil, nil, nil, nil, nil, nil, nil, 500, nil, 'response_body') }
  let(:env_other) { Faraday::Env.new(:get, nil, url, nil, nil, nil, nil, nil, nil, nil, 600, nil, 'response_body') }
  let(:env_with_error) { Faraday::Env.new(:get, nil, url, nil, nil, nil, nil, nil, nil, nil, 400, nil, JSON[error]) }
  let(:env_with_errors) { Faraday::Env.new(:get, nil, url, nil, nil, nil, nil, nil, nil, nil, 400, nil, JSON[errors]) }
  let(:env_w_icn) { Faraday::Env.new(:get, nil, url_w_icn, nil, nil, nil, nil, nil, nil, nil, 400, nil, JSON[errors]) }

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
          expect(e.response_values[:detail]).to equal('response_body')
          expect(e.response_values[:source][:vamf_url]).to equal(url)
          expect(e.response_values[:source][:vamf_body]).to equal('response_body')
          expect(e.response_values[:source][:vamf_status]).to equal(400)
        }
      end
    end

    context 'with a 403 error' do
      it 'raises VAOS_403 BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_403) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_403')
          expect(e.response_values[:detail]).to equal('response_body')
          expect(e.response_values[:source][:vamf_url]).to equal(url)
          expect(e.response_values[:source][:vamf_body]).to equal('response_body')
          expect(e.response_values[:source][:vamf_status]).to equal(403)
        }
      end
    end

    context 'with a 404 error' do
      it 'raises VAOS_404 BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_404) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_404')
          expect(e.response_values[:detail]).to equal('response_body')
          expect(e.response_values[:source][:vamf_url]).to equal(url)
          expect(e.response_values[:source][:vamf_body]).to equal('response_body')
          expect(e.response_values[:source][:vamf_status]).to equal(404)
        }
      end
    end

    context 'with 409 errors' do
      it 'raises a VAOS_409A BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_409) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_409A')
          expect(e.response_values[:detail]).to equal('response_body')
          expect(e.response_values[:source][:vamf_url]).to equal(url)
          expect(e.response_values[:source][:vamf_body]).to equal('response_body')
          expect(e.response_values[:source][:vamf_status]).to equal(409)
        }
      end
    end

    context 'with a 500..510 error' do
      it 'raises VAOS_502 error' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_500) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VAOS_502')
          expect(e.response_values[:detail]).to equal('response_body')
          expect(e.response_values[:source][:vamf_url]).to equal(url)
          expect(e.response_values[:source][:vamf_body]).to equal('response_body')
          expect(e.response_values[:source][:vamf_status]).to equal(500)
        }
      end
    end

    context 'with all other errors' do
      it 'raises a VA900 error' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_other) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.key).to equal('VA900')
          expect(e.response_values[:detail]).to equal('response_body')
          expect(e.response_values[:source][:vamf_url]).to equal(url)
          expect(e.response_values[:source][:vamf_body]).to equal('response_body')
          expect(e.response_values[:source][:vamf_status]).to equal(600)
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

      it 'hashes the icn in the uri' do
        expected_uri = URI('https://veteran.apps.va.gov/id/441ab560b8fc574c6bf84d6c6105318b79455321a931ef701d39f4ff91894c64')
        err = VAOS::Middleware::Response::Errors.new

        expect { err.on_complete(env_w_icn) }.to raise_error(VAOS::Exceptions::BackendServiceException) { |e|
          expect(e.response_values.dig(:source, :vamf_url)).to eql(expected_uri)
        }
      end
    end
  end
end
