# frozen_string_literal: true

require 'rails_helper'

describe Forms::Client do
  subject { described_class.new(search_term) }

  let(:search_term) { nil }

  describe '#get_all' do
    context 'with no query' do
      it 'returns a form response object' do
        VCR.use_cassette('forms/200_all_forms') do
          response = subject.get_all
          expect(response).to be_a Forms::Responses::Response
        end
      end
    end

    context 'with a query' do
      let(:search_term) { 'health' }

      it 'returns a form response object' do
        VCR.use_cassette('forms/200_form_query') do
          response = subject.get_all
          expect(response).to be_a Forms::Responses::Response
        end
      end
    end

    context 'with an http timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      end

      it 'logs an error and raise GatewayTimeout exception' do
        expect(StatsD).to receive(:increment).once.with(
          'api.forms.get_all.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.forms.get_all.total')
        expect { subject.get_all }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    context 'with a client error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Common::Client::Errors::ClientError)
      end

      it 'raises backend exception' do
        expect(StatsD).to receive(:increment).once.with(
          'api.forms.get_all.fail', tags: ['error:Common::Client::Errors::ClientError']
        )
        expect(StatsD).to receive(:increment).once.with('api.forms.get_all.total')
        expect { subject.get_all }.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end
end
