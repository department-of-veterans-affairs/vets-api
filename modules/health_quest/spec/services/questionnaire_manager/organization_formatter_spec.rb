# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::OrganizationFormatter do
  subject { described_class }

  let(:org) do
    double('Organization', resource: double('Resource',
                                            identifier: [double('first'), double('last', value: 'vha_333')],
                                            telecom: []))
  end
  let(:orgs_array) { [org] }
  let(:facilities) { [{ 'id' => 'vha_333', 'attributes' => { 'phone' => { 'main' => '555-555-5555' } } }] }

  describe '.build' do
    it 'returns an instance of subject' do
      expect(subject.build([], [])).to be_a(HealthQuest::QuestionnaireManager::OrganizationFormatter)
    end
  end

  describe 'attributes' do
    it 'responds to orgs_array' do
      expect(subject.build([], []).respond_to?(:orgs_array)).to be(true)
    end
  end

  describe '#to_h' do
    it 'builds a formatted hash' do
      expect(subject.build(orgs_array, facilities).to_h).to eq({ 'vha_333' => org })
    end
  end

  describe '#add_phones_to_org' do
    it 'adds phone number to org' do
      with_phone = subject.build(orgs_array, facilities).add_phones_to_org(org)

      expect(with_phone.resource.telecom.first).to be_a(FHIR::ContactPoint)
    end
  end

  describe '#facilities_by_ids' do
    it 'formats facilities by ids' do
      hash = { 'vha_333' => { 'id' => 'vha_333', 'attributes' => { 'phone' => { 'main' => '555-555-5555' } } } }

      expect(subject.build(orgs_array, facilities).facilities_by_ids).to eq(hash)
    end
  end
end
