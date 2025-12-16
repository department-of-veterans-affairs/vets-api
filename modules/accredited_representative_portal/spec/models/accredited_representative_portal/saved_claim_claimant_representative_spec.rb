# frozen_string_literal: true

require 'rails_helper'

# Minimal class so verified doubles can reference a constant.
class DummyPOAHolder
  def initialize(hash) = @hash = hash
  def to_h = @hash
end

RSpec.describe AccreditedRepresentativePortal::SavedClaimClaimantRepresentative, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  subject(:model) { build(:saved_claim_claimant_representative, saved_claim:) }

  let(:saved_claim) { create(:saved_claim_benefits_intake) }

  # Shortcuts to constants (properly namespaced)
  let(:poa_types_all) do
    AccreditedRepresentativePortal::PowerOfAttorneyHolder::Types::ALL
  end
  let(:poa_primary_keys) do
    AccreditedRepresentativePortal::PowerOfAttorneyHolder::PRIMARY_KEY_ATTRIBUTE_NAMES
  end
  let(:claimant_types_mod) do
    described_class::ClaimantTypes
  end

  before do
    # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
    # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
    allow(FastImage).to receive(:size).and_wrap_original do |original, file|
      if file.respond_to?(:path) && file.path.end_with?('.pdf')
        nil
      else
        original.call(file)
      end
    end
  end

  describe 'associations' do
    it 'belongs to saved_claim (::SavedClaim)' do
      expect(described_class.reflect_on_association(:saved_claim).klass).to eq(SavedClaim)
    end
  end

  describe 'validations' do
    it 'validates inclusion of power_of_attorney_holder_type' do
      # Factory should already be valid
      expect(model).to be_valid

      model.power_of_attorney_holder_type = 'NOT_A_TYPE'
      expect(model).not_to be_valid
      expect(model.errors[:power_of_attorney_holder_type]).to be_present
    end

    it 'wires enum claimant_type to ClaimantTypes::ALL' do
      expect(described_class.claimant_types.keys)
        .to match_array(claimant_types_mod::ALL.map(&:to_s))
    end
  end

  describe 'delegations' do
    it 'delegates selected methods to saved_claim' do
      expect(model).to respond_to(
        :form_id, :display_form_id, :parsed_form, :guid, :latest_submission_attempt
      )

      allow(saved_claim).to receive(:form_id).and_return('21-686c')
      expect(model.form_id).to eq('21-686c')
    end
  end

  describe 'scopes' do
    describe '.for_power_of_attorney_holders' do
      def poa_hash(suffix)
        poa_primary_keys.index_with { |k| "#{k}-#{suffix}" }
      end

      def prefixed_attrs(hash)
        hash.transform_keys { |k| :"power_of_attorney_holder_#{k}" }
      end

      it 'returns none when given an empty array' do
        create(:saved_claim_claimant_representative, saved_claim:)
        expect(described_class.for_power_of_attorney_holders([])).to be_none
      end
    end

    describe '.sorted_by' do
      it 'sorts by created_at ascending when direction is nil or invalid' do
        r1 = travel_to(Time.zone.parse('2025-01-01 10:00:00')) do
          create(
            :saved_claim_claimant_representative,
            saved_claim: create(:saved_claim_benefits_intake)
          )
        end
        r3 = travel_to(Time.zone.parse('2025-01-01 11:00:00')) do
          create(
            :saved_claim_claimant_representative,
            saved_claim: create(:saved_claim_benefits_intake)
          )
        end
        r2 = travel_to(Time.zone.parse('2025-01-01 12:00:00')) do
          create(
            :saved_claim_claimant_representative,
            saved_claim: create(:saved_claim_benefits_intake)
          )
        end

        expect(described_class.sorted_by('created_at', nil).pluck(:id))
          .to eq([r1.id, r3.id, r2.id])

        expect(described_class.sorted_by('created_at', 'weird').pluck(:id))
          .to eq([r1.id, r3.id, r2.id])
      end

      it 'sorts by created_at descending when requested' do
        r1 = create(
          :saved_claim_claimant_representative,
          saved_claim: create(:saved_claim_benefits_intake),
          created_at: 1.hour.ago
        )
        r2 = create(
          :saved_claim_claimant_representative,
          saved_claim: create(:saved_claim_benefits_intake),
          created_at: Time.zone.now
        )
        r3 = create(
          :saved_claim_claimant_representative,
          saved_claim: create(:saved_claim_benefits_intake),
          created_at: 30.minutes.ago
        )

        expect(described_class.sorted_by('created_at', 'desc').pluck(:id))
          .to eq([r2.id, r3.id, r1.id])
      end

      it 'raises on unsupported column' do
        expect do
          described_class.sorted_by('not_a_column', 'asc')
        end.to raise_error(ArgumentError, /Invalid sort column/)
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation#set_claimant_type' do
      it 'sets claimant_type to DEPENDENT when parsed_form has "dependent"' do
        allow(saved_claim).to receive(:parsed_form)
          .and_return({ 'dependent' => { 'foo' => 'bar' } })

        model.validate
        expect(model.claimant_type).to eq(claimant_types_mod::DEPENDENT)
      end

      it 'sets claimant_type to VETERAN when parsed_form has "veteran" and not "dependent"' do
        allow(saved_claim).to receive(:parsed_form)
          .and_return({ 'veteran' => { 'name' => 'Bob' } })

        model.validate
        expect(model.claimant_type).to eq(claimant_types_mod::VETERAN)
      end

      it 'leaves claimant_type nil when neither key is present' do
        allow(saved_claim).to receive(:parsed_form)
          .and_return({ 'something_else' => true })

        model.validate
        expect(model.claimant_type).to be_nil
      end
    end
  end
end
