# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleFormsApi::VBA210845 do
  describe 'zip_code_is_us_based' do
    subject(:zip_code_is_us_based) { described_class.new(data).zip_code_is_us_based }

    context 'authorizer address is present and in US' do
      let(:data) { { 'authorizer_address' => { 'country' => 'USA' } } }

      it 'returns true' do
        expect(zip_code_is_us_based).to eq(true)
      end
    end

    context 'authorizer address is present and not in US' do
      let(:data) { { 'authorizer_address' => { 'country' => 'Canada' } } }

      it 'returns false' do
        expect(zip_code_is_us_based).to eq(false)
      end
    end

    context 'person is present and in US' do
      let(:data) { { 'person_address' => { 'country' => 'USA' } } }

      it 'returns true' do
        expect(zip_code_is_us_based).to eq(true)
      end
    end

    context 'person is present and not in US' do
      let(:data) { { 'person_address' => { 'country' => 'Canada' } } }

      it 'returns false' do
        expect(zip_code_is_us_based).to eq(false)
      end
    end

    context 'organization is present and in US' do
      let(:data) do
        { 'organization_address' => { 'country' => 'USA' } }
      end

      it 'returns true' do
        expect(zip_code_is_us_based).to eq(true)
      end
    end

    context 'organization is present and not in US' do
      let(:data) do
        { 'organization_address' => { 'country' => 'Canada' } }
      end

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
