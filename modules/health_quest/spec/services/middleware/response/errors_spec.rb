# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/fixture_helper'

class BackendServiceException
end

describe HealthQuest::Middleware::Response::Errors do
  let(:env) { OpenStruct.new('success?' => false, status: 'status', body: {}) }
  let(:env_400) { OpenStruct.new('success?' => false, status: 400, body: {}) }
  let(:env_404) { OpenStruct.new('success?' => false, status: 404, body: {}) }
  let(:env_403) { OpenStruct.new('success?' => false, status: 403, body: {}) }
  let(:env_500) { OpenStruct.new('success?' => false, status: 500, body: {}) }

  let(:expected_exception) { Common::Exceptions::BackendServiceException }

  it 'handles errors' do
    expect { described_class.new.on_complete(env) }.to raise_error(expected_exception, /VA900/)
  end
  it 'handles 400 errors' do
    expect { described_class.new.on_complete(env_400) }.to raise_error(expected_exception, /HEALTH_QUEST_400/)
  end
  it 'handles 403 errors' do
    expect { described_class.new.on_complete(env_403) }.to raise_error(expected_exception, /HEALTH_QUEST_403/)
  end
  it 'handles 404 errors' do
    expect { described_class.new.on_complete(env_404) }.to raise_error(expected_exception, /HEALTH_QUEST_404/)
  end
  it 'handles 500 errors' do
    expect { described_class.new.on_complete(env_500) }.to raise_error(expected_exception, /HEALTH_QUEST_502/)
  end
end
