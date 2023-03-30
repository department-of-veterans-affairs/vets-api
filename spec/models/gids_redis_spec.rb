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
    it 'delegates to `GI::Client`' do
      allow_any_instance_of(GI::Client).to receive(:get_institution_details_v0).and_return(gids_response)

      expect(subject.get_institution_details_v0(scrubbed_params)).to eq(gids_response.body)
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
