# frozen_string_literal: true

require 'rails_helper'
require './rakelib/support/sessions_file_serializer.rb'

describe SessionsArgSerializer do
  describe '#generate_cookies_sessions' do
    let(:sessions) { JSON.parse(described_class.new(args).generate_cookies_sessions) }

    context 'with nil args' do
      let(:args) { Rake::TaskArguments.new(%i[count mhv_id], [nil, nil]) }

      it 'outputs 50 sessions' do
        expect(sessions.count).to eq(50)
      end
    end

    context 'with 10 count arg' do
      let(:args) { Rake::TaskArguments.new(%i[count mhv_id], [10, nil]) }

      it 'outputs 10 sessions' do
        expect(sessions.count).to eq(10)
      end
    end

    context 'with a mhv_id arg' do
      def decrypt_sso_cookie(cookie)
        JSON.parse(SSOEncryptor.decrypt(cookie))
      end

      let(:mhv_id) { 'MHV123' }
      let(:args) { Rake::TaskArguments.new(%i[count mhv_id], [1, mhv_id]) }
      let(:decrypted_sso_header) do
        decrypt_sso_cookie(sessions.first['cookie_header'].match(/#{Settings.sso.cookie_name}=(.*)$/).captures.first)
      end

      it 'subs in the mhv id' do
        expect(decrypted_sso_header['mhvCorrelationId']).to eq(mhv_id)
      end
    end
  end
end
