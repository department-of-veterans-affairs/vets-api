# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::DependentClaimFactory, type: :model do
  let(:form_data) { { 'test' => 'data' } }
  let(:parent_id) { 123 }
  let(:factory) { described_class.new(form_data, parent_id) }

  describe 'initialization' do
    it 'stores form_data and parent_id' do
      expect(factory.instance_variable_get(:@form_data)).to eq(form_data)
      expect(factory.instance_variable_get(:@parent_id)).to eq(parent_id)
    end
  end

  describe '#generate' do
    it 'raises NotImplementedError when called on abstract base class' do
      allow(factory).to receive(:extract_form_data).and_raise(NotImplementedError,
                                                              'Subclasses must implement extract_form_data')

      expect { factory.generate }.to raise_error(NotImplementedError, 'Subclasses must implement extract_form_data')
    end
  end

  describe 'private methods' do
    describe '#extract_form_data' do
      it 'raises NotImplementedError' do
        expect do
          factory.send(:extract_form_data)
        end.to raise_error(NotImplementedError, 'Subclasses must implement extract_form_data')
      end
    end

    describe '#form_id' do
      it 'raises NotImplementedError' do
        expect { factory.send(:form_id) }.to raise_error(NotImplementedError, 'Subclasses must implement form_id')
      end
    end

    describe '#create_claim' do
      let(:extracted_data) { { 'extracted' => 'data' } }
      let(:mock_claim) { instance_double(DependentsBenefits::SavedClaim, id: 456) }

      before do
        allow(factory).to receive(:form_id).and_return('test-form-id')
        allow(DependentsBenefits::SavedClaim).to receive(:new).and_return(mock_claim)
        allow(mock_claim).to receive(:validate!)
        allow(mock_claim).to receive(:save!)
      end

      it 'creates a SavedClaim with the correct data and form_id' do
        factory.send(:create_claim, extracted_data)

        expect(DependentsBenefits::SavedClaim).to have_received(:new).with(
          form: extracted_data.to_json,
          form_id: 'test-form-id'
        )
        expect(mock_claim).to have_received(:save!)
      end

      it 'returns the created claim' do
        result = factory.send(:create_claim, extracted_data)
        expect(result).to eq(mock_claim)
      end
    end

    describe '#create_claim_group_item' do
      let(:mock_claim) { instance_double(DependentsBenefits::SavedClaim, id: 456) }

      before do
        allow(Rails.logger).to receive(:info)
      end

      it 'logs a TODO message for claim linking' do
        factory.send(:create_claim_group_item, mock_claim)

        expect(Rails.logger).to have_received(:info).with("TODO: Link claim 456 to parent #{parent_id}")
      end

      it 'returns nil (stubbed method)' do
        result = factory.send(:create_claim_group_item, mock_claim)
        expect(result).to be_nil
      end
    end
  end
end
