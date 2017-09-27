# frozen_string_literal: true
require 'rails_helper'

describe EMISRedis::Model do
  let(:user) { build :loa3_user }
  let(:model) { described_class.for_user(user) }

  describe '#emis_response' do
    let(:response) { double }

    before do
      expect(model).to receive(:response_from_redis_or_service).with(:foo).and_return(response)
    end

    def call_emis_response
      model.send(:emis_response, :foo)
    end

    context 'with a response error' do
      before do
        expect(response).to receive(:error?).and_return(true)
        expect(response).to receive(:error).and_return('error')
      end

      it 'should raise the response error' do
        expect { call_emis_response }.to raise_error('error')
      end
    end

    context 'with no response error' do
      before do
        expect(response).to receive(:error?).and_return(false)
      end

      it 'should return response' do
        expect(call_emis_response).to eq(response)
      end
    end
  end
end
