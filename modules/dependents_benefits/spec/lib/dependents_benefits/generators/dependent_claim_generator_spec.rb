# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/generators/dependent_claim_generator'

RSpec.describe DependentsBenefits::Generators::DependentClaimGenerator, type: :model do
  before do
    allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
    allow_any_instance_of(SavedClaim).to receive(:pdf_overflow_tracking)

    allow(generator).to receive(:claim_class).and_return(DependentsBenefits::PrimaryDependencyClaim)
  end

  let(:form_data) { { 'test' => 'data' } }
  let(:parent_id) { 123 }
  let(:generator) { described_class.new(form_data, parent_id) }

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

      describe '#claim_class' do
        it 'raises NotImplementedError' do
          allow(generator).to receive(:claim_class).and_call_original
          expect do
            generator.send(:claim_class)
          end.to raise_error(NotImplementedError, 'Subclasses must implement claim_class')
        end
      end
    end

    describe '#create_claim' do
      let(:extracted_data) { { 'extracted' => 'data' } }
      let(:mock_claim) { instance_double(DependentsBenefits::PrimaryDependencyClaim, id: 456) }

      before do
        allow(DependentsBenefits::PrimaryDependencyClaim).to receive(:new).and_return(mock_claim)
        allow(mock_claim).to receive(:validate!)
        allow(mock_claim).to receive(:save!)
      end

      it 'creates a SavedClaim with the correct data and form_id' do
        generator.send(:create_claim, extracted_data)

        expect(DependentsBenefits::PrimaryDependencyClaim).to have_received(:new).with(form: extracted_data.to_json)
        expect(mock_claim).to have_received(:save!)
      end

      it 'returns the created claim' do
        result = generator.send(:create_claim, extracted_data)
        expect(result).to eq(mock_claim)
      end
    end

    describe '#create_claim_group_item' do
      let(:parent_claim) { create(:dependents_claim) }
      let(:child_claim) { create(:student_claim) }
      let(:parent_claim_group) do
        create(:saved_claim_group,
               claim_group_guid: parent_claim.guid,
               parent_claim_id: parent_claim.id,
               saved_claim_id: parent_claim.id)
      end
      let(:parent_id) { parent_claim.id }

      it 'creates a claim group child item' do
        expect(SavedClaimGroup).to receive(:new).with(
          claim_group_guid: parent_claim_group.claim_group_guid,
          parent_claim_id: parent_claim.id,
          saved_claim_id: child_claim.id
        ).and_call_original

        result = generator.send(:create_claim_group_item, child_claim)
        expect(result).to be_a(SavedClaimGroup)
      end
    end
  end
end
