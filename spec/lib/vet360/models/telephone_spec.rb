# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Models::Telephone do
  describe 'is_international' do
    let(:data) { JSON.parse(telephone.in_json) }
    let(:is_international) { data['bio']['internationalIndicator'] }

    context 'when explicitly set' do
      let(:telephone) { build(:telephone, is_international: true) }

      it 'equals the input value' do
        expect(is_international).to eq(true)
      end
    end

    context 'when nil' do
      context 'when country_code is nil' do
        let(:telephone) { build(:telephone, is_international: nil, country_code: nil) }

        it 'defaults to false' do
          expect(is_international).to eq(false)
        end
      end

      context 'when country_code is domestic' do
        let(:telephone) { build(:telephone, is_international: nil, country_code: '1') }
        it 'is false' do
          expect(is_international).to eq(false)
        end
      end

      context 'when country_code is international' do
        let(:telephone) { build(:telephone, is_international: nil, country_code: '44') }
        it 'is true' do
          expect(is_international).to eq(true)
        end
      end
    end
  end
end
