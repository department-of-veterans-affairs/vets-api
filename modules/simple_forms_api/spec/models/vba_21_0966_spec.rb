# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SimpleFormsApi::VBA210966' do
  describe 'zip_code_is_us_based' do
    describe 'veteran address is present and in US' do
      it 'returns true' do
        data = { 'veteran_address' => { 'country' => 'USA' } }

        form = SimpleFormsApi::VBA210966.new(data)

        expect(form.zip_code_is_us_based).to eq(true)
      end
    end

    describe 'veteran address is present and not in US' do
      it 'returns false' do
        data = { 'veteran_address' => { 'country' => 'Canada' } }

        form = SimpleFormsApi::VBA210966.new(data)

        expect(form.zip_code_is_us_based).to eq(false)
      end
    end

    describe 'surviving dependent is present and in US' do
      it 'returns true' do
        data = { 'surviving_dependent_address' => { 'country' => 'USA' } }

        form = SimpleFormsApi::VBA210966.new(data)

        expect(form.zip_code_is_us_based).to eq(true)
      end
    end

    describe 'surviving dependent is present and not in US' do
      it 'returns false' do
        data = { 'surviving_dependent_address' => { 'country' => 'Canada' } }

        form = SimpleFormsApi::VBA210966.new(data)

        expect(form.zip_code_is_us_based).to eq(false)
      end
    end
  end
end
