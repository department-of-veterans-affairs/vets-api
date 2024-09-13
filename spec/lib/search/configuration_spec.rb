# frozen_string_literal: true

require 'rails_helper'

describe Search::Configuration do
  describe '#service_name' do
    it 'has the expected service name' do
      expect(described_class.instance.service_name).to eq('Search/Results')
    end
  end

  describe '#base_path' do
    context 'search_use_v2_gsa Flipper is enabled' do
      before do
        Flipper.enable(:search_use_v2_gsa)
      end

      it 'provides api.gsa.gov search URL' do
        expect(described_class.instance.base_path).to eq('https://api.gsa.gov/technology/searchgov/v2/results/i14y')
      end
    end

    context 'search_use_v2_gsa Flipper is disabled' do
      before do
        Flipper.disable(:search_use_v2_gsa)
      end

      it 'provides search.usa.gov search URL' do
        expect(described_class.instance.base_path).to eq('https://search.usa.gov/api/v2/search/i14y')
      end
    end

    context 'Flipper raises a ActiveRecord::NoDatabaseError' do
      before do
        expect(Flipper).to receive(:enabled?).and_return(ActiveRecord::NoDatabaseError)
      end

      it 'provides search.usa.gov search URL' do
        expect(described_class.instance.base_path).to eq('https://search.usa.gov/api/v2/search/i14y')
      end
    end
  end
end
