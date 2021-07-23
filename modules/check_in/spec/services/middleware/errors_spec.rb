# frozen_string_literal: true

require 'rails_helper'

Faraday::Middleware.register_middleware(check_in_logging: Middleware::CheckInLogging)
Faraday::Response.register_middleware(check_in_errors: Middleware::Errors)

describe Middleware::Errors do
  subject { described_class.new }

  describe '#on_complete' do
    let(:expected_exception) { Common::Exceptions::BackendServiceException }
    let(:env_success) { OpenStruct.new('success?' => true) }
    let(:env_400) { OpenStruct.new('success?' => false, status: 400, body: {}) }
    let(:env_403) { OpenStruct.new('success?' => false, status: 403, body: {}) }
    let(:env_404) { OpenStruct.new('success?' => false, status: 404, body: {}) }
    let(:env_500) { OpenStruct.new('success?' => false, status: 500, body: {}) }
    let(:env) { OpenStruct.new('success?' => false, status: 'status', body: {}, url: '') }

    it 'returns nil on env success' do
      expect(subject.on_complete(env_success)).to be_nil
    end

    it 'captures extra context' do
      expect(Raven).to receive(:extra_context).with({ message: {}, url: '' }).once

      expect { subject.on_complete(env) }.to raise_error(expected_exception, /VA900/)
    end

    it 'handles unspecified errors' do
      expect { subject.on_complete(env) }.to raise_error(expected_exception, /VA900/)
    end

    it 'handles 400 errors' do
      expect { subject.on_complete(env_400) }.to raise_error(expected_exception, /CHECK_IN_400/)
    end

    it 'handles 403 errors' do
      expect { subject.on_complete(env_403) }.to raise_error(expected_exception, /CHECK_IN_403/)
    end

    it 'handles 404 errors' do
      expect { subject.on_complete(env_404) }.to raise_error(expected_exception, /CHECK_IN_404/)
    end

    it 'handles 500 errors' do
      expect { subject.on_complete(env_500) }.to raise_error(expected_exception, /CHECK_IN_502/)
    end
  end
end
