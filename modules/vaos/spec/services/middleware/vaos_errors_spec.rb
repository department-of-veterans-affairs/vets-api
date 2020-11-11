# frozen_string_literal: true

require 'rails_helper'

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
  let(:env_400) { MyEnv.new(400, 'body', 'url', false) }
  let(:env_403) { MyEnv.new(403, 'body', 'url', false) }
  let(:env_404) { MyEnv.new(404, 'body', 'url', false) }
  let(:env_500) { MyEnv.new(500, 'body', 'url', false) }
  let(:env_500a) { MyEnv.new(500, '814 CLINIC_RESTRICTED_TO_PRIVILEGED_USERS: APTCRGT^Appt.', 'url', false) }

  describe 'on complete' do
    context 'with 400, 409 errors' do
      it 'raises a VAOS_400 BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_400) }.to raise_error(Common::Exceptions::BackendServiceException) { |error|
          expect(error.key).to equal('VAOS_400')
        }
      end
    end

    context 'with a 403 error' do
      it 'raises VAOS_403 BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_403) }.to raise_error(Common::Exceptions::BackendServiceException) { |error|
          expect(error.key).to equal('VAOS_403')
        }
      end
    end

    context 'with a 404 error' do
      it 'raises VAOS_404 BackendServiceException' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_404) }.to raise_error(Common::Exceptions::BackendServiceException) { |error|
          expect(error.key).to equal('VAOS_404')
        }
      end
    end

    context 'with a 500..510 error' do
      it 'raises VAOS_502 error' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_500) }.to raise_error(Common::Exceptions::BackendServiceException) { |error|
          expect(error.key).to equal('VAOS_502')
        }
      end
    end

    context 'with a 500 vamf status on cancelled appointments' do
      it 'raises VAOS_400 error' do
        err = VAOS::Middleware::Response::Errors.new
        expect { err.on_complete(env_500a) }.to raise_error(Common::Exceptions::BackendServiceException) { |error|
          expect(error.key).to equal('VAOS_400')
        }
      end
    end
  end
end
