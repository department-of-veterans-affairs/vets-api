# frozen_string_literal: true

require 'rails_helper'

describe EMISRedis::Model do
  let(:user) { build(:user, :loa3) }
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
      let(:response2) { double }

      before do
        [response, response2].each do |res|
          allow(res).to receive(:error?).and_return(false)
        end
      end

      it 'should cache by method name' do
        expect(model).to receive(:response_from_redis_or_service).with(:foo2).and_return(response2)
        call_emis_response
        expect(model.send(:emis_response, :foo2)).to eq(response2)
      end

      it 'should return response' do
        expect(call_emis_response).to eq(response)
      end
    end
  end
end
