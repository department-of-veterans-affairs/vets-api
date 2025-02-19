# frozen_string_literal: true

require 'rails_helper'
require 'legacy_filter_query_rewrite_middleware'

RSpec.describe LegacyFilterQueryRewriteMiddleware, type: :request do
  let(:app) { ->(env) { [200, env, 'app'] } }
  let(:middleware) { described_class.new(app) }

  context 'when the QUERY_STRING contains legacy filter syntax' do
    let(:query_string) { 'filter[[disp_status][eq]]=Active,Expired&other=123' }
    let(:env) { { 'QUERY_STRING' => query_string } }

    it 'rewrites legacy syntax to RFC‑compliant syntax' do
      _status, new_env, _body = middleware.call(env)
      expect(new_env['QUERY_STRING']).to include('filter[disp_status][eq]=Active,Expired')
      expect(new_env['QUERY_STRING']).not_to include('filter[[disp_status][eq]]=')
    end

    it 'preserves other query parameters' do
      _status, new_env, _body = middleware.call(env)
      expect(new_env['QUERY_STRING']).to include('other=123')
    end
  end

  context 'when the QUERY_STRING is already RFC‑compliant' do
    let(:query_string) { 'filter[disp_status][eq]=Active,Expired&other=123' }
    let(:env) { { 'QUERY_STRING' => query_string } }

    it 'leaves the query string unchanged' do
      _status, new_env, _body = middleware.call(env)
      expect(new_env['QUERY_STRING']).to eq(query_string)
    end
  end

  context 'when there is no QUERY_STRING' do
    let(:env) { {} }

    it 'does not modify the environment' do
      _status, new_env, _body = middleware.call(env)
      expect(new_env).not_to have_key('QUERY_STRING')
    end
  end
end
