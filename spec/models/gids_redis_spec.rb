# frozen_string_literal: true

require 'rails_helper'

describe GIDSRedis do
  subject { GIDSRedis.new }

  let(:scrubbed_params) { {} }
  let(:body) { {} }
  let(:gids_response) do
    GI::GIDSResponse.new(status: 200, body:)
  end

  context 'when `GIDSRedis` responds to method' do
    context 'and the method belongs to `GI::Client`' do
      it 'delegates to `GI::Client`' do
        allow_any_instance_of(GI::Client).to receive(:get_institution_details_v0).and_return(gids_response)

        expect(subject.get_institution_details_v0(scrubbed_params)).to eq(gids_response.body)
      end
    end

    context 'and the method belongs to `GI::SearchClient`' do
      it 'delegates to `GI::SearchClient`' do
        allow_any_instance_of(GI::SearchClient).to receive(:get_institution_search_results_v0).and_return(gids_response)

        expect(subject.get_institution_search_results_v0(scrubbed_params)).to eq(gids_response.body)
      end
    end

    context 'and the method belongs to `GI::LCPE::Client`' do
      it 'delegates to `GI::LCPE::Client`' do
        allow_any_instance_of(GI::LCPE::Client).to(
          receive(:get_licenses_and_certs_v1).and_return(gids_response)
        )
        expect(subject.get_licenses_and_certs_v1(scrubbed_params)).to eq(gids_response.body)
      end
    end
  end

  context 'when `GIDSRedis` does not respond to method' do
    it 'calls `super`' do
      expect { subject.not_a_real_method }.to raise_error(NoMethodError)
    end
  end

  describe 'cached attributes' do
    context 'when the cache is empty' do
      it 'caches and return the response', :aggregate_failures do
        allow_any_instance_of(GI::Client).to receive(:get_calculator_constants_v0).and_return(gids_response)

        expect(subject.redis_namespace).to receive(:set).once
        expect(subject.get_calculator_constants_v0(scrubbed_params)).to be_a(Hash)
      end
    end

    context 'when there is cached data' do
      it 'returns the cached data', :aggregate_failures do
        subject.cache(
          :get_calculator_constants_v0.to_s + scrubbed_params.to_s,
          gids_response
        )
        expect_any_instance_of(GI::Client).not_to receive(:get_calculator_constants_v0).with(scrubbed_params)
        expect(subject.get_calculator_constants_v0(scrubbed_params)).to be_a(Hash)
      end
    end
  end
end
