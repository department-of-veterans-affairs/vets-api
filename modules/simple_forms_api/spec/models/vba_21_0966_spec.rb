# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VBA210966 do
  describe 'zip_code_is_us_based' do
    subject(:zip_code_is_us_based) { described_class.new(data).zip_code_is_us_based }

    context 'veteran address is present and in US' do
      let(:data) { { 'veteran_mailing_address' => { 'country' => 'USA' } } }

      it 'returns true' do
        expect(zip_code_is_us_based).to eq(true)
      end
    end

    context 'veteran address is present and not in US' do
      let(:data) { { 'veteran_mailing_address' => { 'country' => 'Canada' } } }

      it 'returns false' do
        expect(zip_code_is_us_based).to eq(false)
      end
    end

    context 'surviving dependent is present and in US' do
      let(:data) { { 'surviving_dependent_mailing_address' => { 'country' => 'USA' } } }

      it 'returns true' do
        expect(zip_code_is_us_based).to eq(true)
      end
    end

    context 'surviving dependent is present and not in US' do
      let(:data) { { 'surviving_dependent_mailing_address' => { 'country' => 'Canada' } } }

      it 'returns false' do
        expect(zip_code_is_us_based).to eq(false)
      end
    end

    context 'no valid address is given' do
      let(:data) { {} }

      it 'returns false' do
        expect(zip_code_is_us_based).to eq(false)
      end
    end
  end
end
