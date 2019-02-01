# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RateLimitedSearch do
  describe '#create_or_increment_count' do
    let(:params) { '1234' }
    let(:hashed_params) { Digest::SHA2.hexdigest(params) }

    context 'when an existing search doesnt exist' do
      it 'should create a new model' do
        described_class.create_or_increment_count(params)
        expect(described_class.find(hashed_params).count).to eq(1)
      end
    end

    context 'when an existing search exists' do
      let!(:rate_limited_search) { create(:rate_limited_search) }

      it 'should increment the count' do
        described_class.create_or_increment_count(params)
        expect(described_class.find(hashed_params).count).to eq(2)
      end

      context 'when an existing search exists with max count' do
        it 'should raise a rate limited error' do
          rate_limited_search.count = 3
          rate_limited_search.save!

          expect do
            described_class.create_or_increment_count(params)
          end.to raise_error(RateLimitedSearch::RateLimitedError)
        end
      end
    end
  end
end
