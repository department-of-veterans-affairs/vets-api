# frozen_string_literal: true

require 'rails_helper'

describe Benchmark::Whitelist do
  describe '.authorize!' do
    context 'with tags that are whitelisted' do
      let(:whitelisted_paths) { Benchmark::Whitelist::WHITELIST }

      it 'returns the array of passed tags' do
        results = Benchmark::Whitelist.new(whitelisted_paths).authorize!

        expect(results).to eq whitelisted_paths
      end
    end

    context 'with a tag that is not whitelisted' do
      let(:bad_tag) { ['some_random_tag'] }

      it 'raises a Common::Exceptions::Forbidden error', :aggregate_failures do
        expect { Benchmark::Whitelist.new(bad_tag).authorize! }.to raise_error do |error|
          expect(error).to be_a Common::Exceptions::Forbidden
          expect(error.message).to eq 'Forbidden'
          expect(error.status_code).to eq 403
        end
      end
    end
  end
end
