require 'rails_helper'

RSpec.describe RateLimitedSearch do
  describe('.truncate_ssn') do
    it 'should get the first 3 and last 4 of the ssn' do
      expect(described_class.truncate_ssn('111-55-1234')).to eq(
        '1111234'
      )
    end
  end

  describe '#create_or_increment_count' do
    let(:params) { '1234' }

    context 'when an existing search doesnt exist' do
      it 'should create a new model' do
        described_class.create_or_increment_count(params)
        expect(described_class.find(params).count).to eq(1)
      end
    end

    context 'when an existing search exists' do
      let!(:rate_limited_search) { create(:rate_limited_search) }

      it 'should increment the count' do
        described_class.create_or_increment_count(params)
        expect(described_class.find(params).count).to eq(2)
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
