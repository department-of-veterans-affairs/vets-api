# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Veteran::Service::OrganizationRepresentative, type: :model do
  describe 'associations' do
    it 'belongs to a representative (keyed by representative_id)' do
      assoc = described_class.reflect_on_association(:representative)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.class_name).to eq('Veteran::Service::Representative')
      expect(assoc.foreign_key.to_s).to eq('representative_id')
      expect(assoc.options[:primary_key].to_s).to eq('representative_id')
    end

    it 'belongs to an organization (keyed by poa)' do
      assoc = described_class.reflect_on_association(:organization)
      expect(assoc.macro).to eq(:belongs_to)
      expect(assoc.class_name).to eq('Veteran::Service::Organization')
      expect(assoc.foreign_key.to_s).to eq('organization_poa')
      expect(assoc.options[:primary_key].to_s).to eq('poa')
    end
  end

  describe 'validations' do
    subject(:org_rep) do
      described_class.new(
        representative_id: representative.representative_id,
        organization_poa: organization.poa
      )
    end

    let!(:representative) do
      Veteran::Service::Representative.create!(
        representative_id: 'REP123',
        first_name: 'Pat',
        last_name: 'Brown',
        poa_codes: ['ABC'], # required by existing model validation
        user_types: ['attorney'] # not required by validation, but commonly present
      )
    end

    let!(:organization) do
      Veteran::Service::Organization.create!(
        poa: 'ABC',
        name: 'Test VSO'
      )
    end

    it 'is valid with representative_id and organization_poa' do
      expect(org_rep).to be_valid
    end

    it 'requires a representative' do
      org_rep.representative = nil
      expect(org_rep).not_to be_valid
      expect(org_rep.errors[:representative]).to be_present
    end

    it 'requires organization_poa' do
      org_rep.organization_poa = nil
      expect(org_rep).not_to be_valid
      expect(org_rep.errors[:organization_poa]).to be_present
    end

    it 'enforces uniqueness on [organization_poa, representative_id]' do
      described_class.create!(
        representative_id: representative.representative_id,
        organization_poa: organization.poa
      )

      dup = described_class.new(
        representative_id: representative.representative_id,
        organization_poa: organization.poa
      )

      expect(dup).not_to be_valid
      expect(dup.errors[:representative_id]).to be_present
    end
  end

  describe 'acceptance_mode enum' do
    it 'defaults to no_acceptance' do
      record = described_class.new(representative_id: 'REP999', organization_poa: 'XYZ')
      expect(record.acceptance_mode).to eq('no_acceptance')
      expect(record).to be_no_acceptance
    end

    it 'supports the allowed values' do
      record = described_class.new(representative_id: 'REP999', organization_poa: 'XYZ')

      record.acceptance_mode = 'any_request'
      expect(record).to be_any_request

      record.acceptance_mode = 'self_only'
      expect(record).to be_self_only

      record.acceptance_mode = 'no_acceptance'
      expect(record).to be_no_acceptance
    end
  end

  describe 'deactivation' do
    let!(:representative) do
      Veteran::Service::Representative.create!(
        representative_id: 'REP123',
        first_name: 'Pat',
        last_name: 'Brown',
        poa_codes: ['ABC'],
        user_types: ['attorney']
      )
    end

    let!(:organization) do
      Veteran::Service::Organization.create!(
        poa: 'ABC',
        name: 'Test VSO'
      )
    end

    describe 'scopes' do
      it 'returns active and deactivated correctly' do
        active = described_class.create!(
          representative_id: representative.representative_id,
          organization_poa: organization.poa,
          deactivated_at: nil
        )

        rep2 = Veteran::Service::Representative.create!(
          representative_id: 'REP124',
          first_name: 'Other',
          last_name: 'Rep',
          poa_codes: ['ABC'],
          user_types: ['attorney']
        )

        deactivated = described_class.create!(
          representative_id: rep2.representative_id,
          organization_poa: organization.poa,
          deactivated_at: 1.day.ago
        )

        expect(described_class.active).to include(active)
        expect(described_class.active).not_to include(deactivated)

        expect(described_class.deactivated).to include(deactivated)
        expect(described_class.deactivated).not_to include(active)
      end
    end

    describe '#activate!' do
      it 'sets deactivated_at to nil and saves when deactivated' do
        org_rep = described_class.create!(
          representative_id: representative.representative_id,
          organization_poa: organization.poa,
          deactivated_at: 1.day.ago
        )

        org_rep.activate!

        expect(org_rep.reload.deactivated_at).to be_nil
      end

      it 'is a no-op when already active' do
        org_rep = described_class.create!(
          representative_id: representative.representative_id,
          organization_poa: organization.poa,
          deactivated_at: nil
        )

        expect(org_rep.activate!).to be(true)
        expect(org_rep.reload.deactivated_at).to be_nil
      end
    end

    describe '#deactivate!' do
      it 'sets deactivated_at to now and saves' do
        org_rep = described_class.create!(
          representative_id: representative.representative_id,
          organization_poa: organization.poa,
          deactivated_at: nil
        )

        before = Time.current
        org_rep.deactivate!
        after = Time.current

        expect(org_rep.reload.deactivated_at).to be_between(before, after)
      end
    end

    describe '.deactivate!' do
      it 'bulk sets deactivated_at for the provided ids' do
        a = described_class.create!(
          representative_id: representative.representative_id,
          organization_poa: organization.poa,
          deactivated_at: nil
        )

        b_rep = Veteran::Service::Representative.create!(
          representative_id: 'REP124',
          first_name: 'Other',
          last_name: 'Rep',
          poa_codes: ['ABC'],
          user_types: ['attorney']
        )

        b = described_class.create!(
          representative_id: b_rep.representative_id,
          organization_poa: organization.poa,
          deactivated_at: nil
        )

        before = Time.current
        updated = described_class.deactivate!([a.id, b.id])
        after = Time.current

        expect(updated).to eq(2)
        expect(a.reload.deactivated_at).to be_between(before, after)
        expect(b.reload.deactivated_at).to be_between(before, after)
      end

      it 'returns 0 for nil/empty ids' do
        expect(described_class.deactivate!(nil)).to eq(0)
        expect(described_class.deactivate!([])).to eq(0)
      end
    end
  end

  describe 'integration sanity' do
    it 'connects a representative and organization via the join record' do
      rep = Veteran::Service::Representative.create!(
        representative_id: 'REP777',
        first_name: 'Test',
        last_name: 'Rep',
        poa_codes: ['AAA'],
        user_types: ['attorney']
      )

      org = Veteran::Service::Organization.create!(
        poa: 'AAA',
        name: 'AAA Org'
      )

      join = described_class.create!(
        representative_id: rep.representative_id,
        organization_poa: org.poa,
        acceptance_mode: 'any_request'
      )

      expect(join.representative).to eq(rep)
      expect(join.organization).to eq(org)
    end
  end
end
