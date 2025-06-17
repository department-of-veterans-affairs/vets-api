# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::PowerOfAttorneyForm, type: :model do
  let(:trait) { nil }

  let(:form) do
    build(
      :power_of_attorney_form,
      trait,
      power_of_attorney_request: build(:power_of_attorney_request)
    )
  end

  describe 'validations' do
    context 'with dependent claimant' do
      let(:trait) { :with_dependent_claimant }

      it 'is valid with compliant data' do
        expect(form).to be_valid
      end

      it 'is invalid with malformed phone number' do
        bad_data = form.parsed_data.deep_dup
        bad_data['dependent']['phone'] = '123-456-7890'

        form.data = bad_data.to_json
        form.instance_variable_set(:@parsed_data, nil)
        form.validate

        expect(form).not_to be_valid
        expect(form.errors[:data]).to include('does not comply with schema')
      end
    end

    context 'with veteran claimant' do
      let(:trait) { :with_veteran_claimant }

      it 'is valid with compliant data' do
        expect(form).to be_valid
      end

      it 'is invalid with missing required field' do
        bad_data = form.parsed_data.deep_dup
        bad_data['veteran'].delete('ssn')

        form.data = bad_data.to_json
        form.instance_variable_set(:@parsed_data, nil)
        form.validate

        expect(form).not_to be_valid
        expect(form.errors[:data]).to include('does not comply with schema')
      end
    end
  end

  describe 'location extraction' do
    context 'with dependent claimant' do
      let(:trait) { :with_dependent_claimant }

      it 'sets claimant location fields from dependent address' do
        form.validate

        expect(form.claimant_city).to eq('Springfield')
        expect(form.claimant_state_code).to eq('IL')
        expect(form.claimant_zip_code).to eq('62704')
      end
    end

    context 'with veteran claimant' do
      let(:trait) { :with_veteran_claimant }

      it 'sets claimant location fields from veteran address if dependent is nil' do
        form.validate

        expect(form.claimant_city).to eq('Springfield')
        expect(form.claimant_state_code).to eq('IL')
        expect(form.claimant_zip_code).to eq('62704')
      end
    end
  end

  describe '#parsed_data' do
    let(:trait) { :with_veteran_claimant }

    it 'returns parsed JSON data as a hash' do
      expect(form.parsed_data).to be_a(Hash)
      expect(form.parsed_data).to have_key('veteran')
    end
  end
end
