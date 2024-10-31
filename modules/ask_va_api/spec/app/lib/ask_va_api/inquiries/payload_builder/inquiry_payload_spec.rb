# frozen_string_literal: true

require 'rails_helper'
require AskVAApi::Engine.root.join('spec', 'support', 'shared_contexts.rb')

RSpec.describe AskVAApi::Inquiries::PayloadBuilder::InquiryPayload do
  subject(:builder) { described_class.new(inquiry_params: params, user: authorized_user) }

  # allow to have access to inquiry_params and translated_payload
  include_context 'shared data'

  let(:cache_data_service) { instance_double(Crm::CacheData) }
  let(:authorized_user) { build(:user, :accountable_with_sec_id, icn: '234', edipi: '123') }
  let(:cached_data) do
    data = File.read('modules/ask_va_api/config/locales/get_optionset_mock_data.json')
    JSON.parse(data, symbolize_names: true)
  end

  before do
    allow(Crm::CacheData).to receive(:new).and_return(cache_data_service)
    allow(cache_data_service).to receive(:call).with(
      endpoint: 'optionset',
      cache_key: 'optionset'
    ).and_return(cached_data)
  end

  describe '#call' do
    let(:params) { inquiry_params[:inquiry] }

    context 'when inquiry_params is received' do
      it 'builds the correct payload' do
        expect(builder.call).to eq(translated_payload)
      end
    end

    context "when there's no user" do
      let(:authorized_user) { nil }

      it 'set LevelOfAuthentication to Unauthenticated' do
        expect(builder.call[:LevelOfAuthentication]).to eq('Unauthenticated')
      end
    end

    context 'when no params are passed' do
      let(:params) { nil }

      it 'raise an error' do
        expect { builder.call }.to raise_error(
          AskVAApi::Inquiries::PayloadBuilder::InquiryPayload::InquiryPayloadError
        )
      end
    end
  end
end
