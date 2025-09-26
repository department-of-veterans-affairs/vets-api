# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/generators/dependent_claim_generator'

RSpec.describe DependentsBenefits::Generators::DependentClaimGenerator, type: :model do
  let(:form_data) { { 'test' => 'data' } }
  let(:parent_id) { create(:dependents_claim).id }
  let(:generator) { described_class.new(form_data, parent_id) }

  before do
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)

    allow(generator).to receive(:claim_class).and_return(DependentsBenefits::SavedClaim)
  end

  describe 'initialization' do
    it 'stores form_data and parent_id' do
      expect(generator.instance_variable_get(:@form_data)).to eq(form_data)
      expect(generator.instance_variable_get(:@parent_id)).to eq(parent_id)
    end
  end

  describe '#generate' do
    it 'raises NotImplementedError when called on abstract base class' do
      allow(generator).to receive(:extract_form_data).and_raise(NotImplementedError,
                                                                'Subclasses must implement extract_form_data')

      expect { generator.generate }.to raise_error(NotImplementedError, 'Subclasses must implement extract_form_data')
    end
  end

  describe 'private methods' do
    describe '#extract_form_data' do
      it 'raises NotImplementedError' do
        expect do
          generator.send(:extract_form_data)
        end.to raise_error(NotImplementedError, 'Subclasses must implement extract_form_data')
      end
    end

    describe '#create_claim' do
      let(:extracted_data) { { 'extracted' => 'data' } }
      let(:mock_claim) { instance_double(DependentsBenefits::SavedClaim, id: 456) }

      before do
        allow(DependentsBenefits::SavedClaim).to receive(:new).and_return(mock_claim)
        allow(mock_claim).to receive(:validate!)
        allow(mock_claim).to receive(:save!)
      end

      it 'creates a SavedClaim with the correct data and form_id' do
        generator.send(:create_claim, extracted_data)

        expect(DependentsBenefits::SavedClaim).to have_received(:new).with(form: extracted_data.to_json)
        expect(mock_claim).to have_received(:save!)
      end

      it 'returns the created claim' do
        result = generator.send(:create_claim, extracted_data)
        expect(result).to eq(mock_claim)
      end
    end

    describe '#create_claim_group_item' do
      let(:mock_claim) { create(:dependents_claim, id: 456) }
      let(:mock_group) { create(:saved_claim_group) }

      before do
        allow(Rails.logger).to receive(:info)
        scope_double = double('scope')
        allow(scope_double).to receive(:first!).and_return(mock_group)
        allow(SavedClaimGroup).to receive(:by_parent_claim).with(parent_id).and_return(scope_double)
      end

      it 'creates a claim group' do
        expect(SavedClaimGroup).to receive(:new).with(
          claim_group_guid: mock_group.claim_group_guid,
          parent_claim_id: parent_id,
          saved_claim_id: mock_claim.id
        ).and_call_original

        generator.send(:create_claim_group_item, mock_claim)
      end

      it 'returns the created claim group' do
        result = generator.send(:create_claim_group_item, mock_claim)
        expect(result).to be_a(SavedClaimGroup)
      end
    end
  end
end
