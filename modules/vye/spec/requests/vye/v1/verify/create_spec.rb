# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::V1::VerificationsController, type: :request do
  let!(:current_user) { create(:user, :loa3) }
  let(:params) { FactoryBot.attributes_for(:vye_verification) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
  end

  describe 'POST /vye/v1/verify with flag turned off' do
    before do
      Flipper.disable :vye_request_allowed
    end

    it 'does not accept the request' do
      post('/vye/v1/verify', params:)
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'POST /vye/v1/verify with flag turned on' do
    before do
      Flipper.enable :vye_request_allowed
    end

    describe 'where current_user is' do
      before do
        allow_any_instance_of(described_class).to receive(:load_user_info).and_return(true)
      end

      describe 'not in VYE' do
        before do
          allow_any_instance_of(described_class).to receive(:user_info).and_return(nil)
        end

        it 'does not accept the request' do
          post('/vye/v1/verify', params:)
          expect(response).to have_http_status(:forbidden)
        end
      end

      describe 'in VYE' do
        let(:user_info) { FactoryBot.create(:vye_user_info, icn: current_user.icn, ssn: current_user.ssn) }
        let(:award) { FactoryBot.create(:vye_award, user_info:) }

        before do
          s =
            Struct.new(:settings, :scrypt_config) do
              include Vye::GenDigest
              settings =
                Config.load_files(
                  Rails.root / 'config/settings.yml',
                  Vye::Engine.root / 'config/settings/test.yml'
                )
              scrypt_config = extract_scrypt_config settings
              new(settings, scrypt_config)
            end

          allow_any_instance_of(Vye::GenDigest::Common)
            .to receive(:scrypt_config)
            .and_return(s.scrypt_config)
          allow_any_instance_of(described_class).to receive(:user_info).and_return(user_info)
        end

        it 'creates a new verification' do
          post('/vye/v1/verify', params:)
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe 'where the request is coming from IVR' do
      let(:ivr_params) do
        { ivr_key: Settings.vye.ivr_key, ssn: '123456789' }.merge(FactoryBot.attributes_for(:vye_verification))
      end
      let(:user_info) { create(:vye_user_info, ssn: ivr_params[:ssn]) }
      let(:award) { create(:vye_award, user_info:) }

      before do
        s =
          Struct.new(:settings, :scrypt_config) do
            include Vye::GenDigest
            settings =
              Config.load_files(
                Rails.root / 'config/settings.yml',
                Vye::Engine.root / 'config/settings/test.yml'
              )
            scrypt_config = extract_scrypt_config settings
            new(settings, scrypt_config)
          end

        allow_any_instance_of(Vye::GenDigest::Common)
          .to receive(:scrypt_config)
          .and_return(s.scrypt_config)
        allow_any_instance_of(described_class).to receive(:user_info).and_return(user_info)
      end

      it 'creates a new verification' do
        post('/vye/v1/verify', params: ivr_params)
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
