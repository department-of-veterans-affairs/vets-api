# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SimpleFormsApi::VBA210845' do
  describe 'zip_code_is_us_based' do
    context 'authorizer address is present and in US' do
      it 'returns true' do
        data = { 'authorizer_address' => { 'country' => 'USA' } }

        form = SimpleFormsApi::VBA210845.new(data)

        expect(form.zip_code_is_us_based).to eq(true)
      end
    end

    context 'authorizer address is present and not in US' do
      it 'returns false' do
        data = { 'authorizer_address' => { 'country' => 'Canada' } }

        form = SimpleFormsApi::VBA210845.new(data)

        expect(form.zip_code_is_us_based).to eq(false)
      end
    end

    context 'person is present and in US' do
      it 'returns true' do
        data = { 'person_address' => { 'country' => 'USA' } }

        form = SimpleFormsApi::VBA210845.new(data)

        expect(form.zip_code_is_us_based).to eq(true)
      end
    end

    context 'person is present and not in US' do
      it 'returns false' do
        data = { 'person_address' => { 'country' => 'Canada' } }

        form = SimpleFormsApi::VBA210845.new(data)

        expect(form.zip_code_is_us_based).to eq(false)
      end
    end

    context 'organization is present and in US' do
      it 'returns true' do
        data = { 'organization_address' => { 'country' => 'USA' } }

        form = SimpleFormsApi::VBA210845.new(data)

        expect(form.zip_code_is_us_based).to eq(true)
      end
    end

    context 'organization is present and not in US' do
      it 'returns false' do
        data = { 'organization_address' => { 'country' => 'Canada' } }

        form = SimpleFormsApi::VBA210845.new(data)

        expect(form.zip_code_is_us_based).to eq(false)
      end
    end

    context 'no valid address is given' do
      it 'returns false' do
        data = {}

        form = SimpleFormsApi::VBA210845.new(data)

        expect(form.zip_code_is_us_based).to eq(false)
      end
    end
  end
end
