# frozen_string_literal: true

require 'rails_helper'
require 'source_app_middleware'

RSpec.describe SourceAppMiddleware, type: :request do
  describe '#call' do
    let(:app) { ->(env) { [200, env, 'app'] } }
    let(:middleware) { described_class.new(app) }
    let(:env) { {} }

    context 'when the source app is in MODULES_APP_NAMES' do
      it 'correctly sets the source app in the environment' do
        allow(Rails).to receive(:env).and_return('development')
        source_app_name = described_class::MODULES_APP_NAMES.to_a.sample
        env['HTTP_SOURCE_APP_NAME'] = source_app_name
        middleware.call(env)
        expect(env['SOURCE_APP']).to eq(source_app_name)
      end
    end

    context 'when the source app is in OTHER_APP_NAMES' do
      it 'correctly sets the source app in the environment' do
        allow(Rails).to receive(:env).and_return('development')
        source_app_name = described_class::OTHER_APP_NAMES.to_a.sample
        env['HTTP_SOURCE_APP_NAME'] = source_app_name
        middleware.call(env)
        expect(env['SOURCE_APP']).to eq(source_app_name)
      end
    end

    context 'when the source app is in FRONT_END_APP_NAMES' do
      it 'correctly sets the source app in the environment' do
        allow(Rails).to receive(:env).and_return('development')
        source_app_name = described_class::FRONT_END_APP_NAMES.to_a.sample
        env['HTTP_SOURCE_APP_NAME'] = source_app_name
        middleware.call(env)
        expect(env['SOURCE_APP']).to eq(source_app_name)
      end
    end

    context 'when the source app is in MOBILE_APP_NAMES' do
      it 'correctly sets the source app in the environment' do
        allow(Rails).to receive(:env).and_return('development')
        source_app_name = described_class::MOBILE_APP_NAMES.to_a.sample
        env['HTTP_SOURCE_APP_NAME'] = source_app_name
        middleware.call(env)
        expect(env['SOURCE_APP']).to eq(source_app_name)
      end
    end

    context 'when the source app is not provided' do
      it 'correctly sets the source app in the environment' do
        allow(Rails).to receive(:env).and_return('development')
        middleware.call(env)
        expect(env['SOURCE_APP']).to eq('not_provided')
      end
    end

    context 'when the source app is in not in the allowlist' do
      it 'correctly sets the source app in the environment' do
        allow(Rails).to receive(:env).and_return('development')
        env['HTTP_SOURCE_APP_NAME'] = 'some_other_app'
        middleware.call(env)
        expect(env['SOURCE_APP']).to eq('not_in_allowlist')
      end
    end
  end
end
