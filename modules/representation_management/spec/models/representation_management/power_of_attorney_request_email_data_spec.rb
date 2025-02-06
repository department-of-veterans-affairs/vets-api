# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::PowerOfAttorneyRequestEmailData, type: :model do
  describe 'validations' do
    subject { described_class.new }

    it { expect(subject).to validate_presence_of(:form_data) }
  end

  describe 'methods' do
    subject { described_class.new(form_data: form_data) }

    let(:organization) { create(:accredited_organization, name: 'Org Name') }
    let(:representative) do
      create(:accredited_individual,
             :for_2122_2122a_pdf_fixture,
             first_name: 'Rep',
             last_name: 'Name')
    end
    let(:form_data) { build(:form_2122_data, organization_id: organization.id, representative_id: representative.id) }

    it 'returns the correct first name if there is no claimant' do
      expect(subject.first_name).to eq('Vet')
    end

    it 'returns the correct last name if there is no claimant' do
      expect(subject.last_name).to eq('Veteran')
    end

    it 'returns the correct first name if there is a claimant' do
      form_data_with_claimant = build(:form_2122_data, :with_claimant, organization_id: organization.id,
                                                                       representative_id: representative.id)
      subject = described_class.new(form_data: form_data_with_claimant)
      expect(subject.first_name).to eq('Claim')
    end

    it 'returns the correct last name if there is a claimant' do
      form_data_with_claimant = build(:form_2122_data, :with_claimant, organization_id: organization.id,
                                                                       representative_id: representative.id)
      subject = described_class.new(form_data: form_data_with_claimant)
      expect(subject.last_name).to eq('Claimant')
    end

    it 'returns the correct submit date' do
      expect(subject.submit_date).to eq(Time.zone.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'))
    end

    it 'returns identical submit time and expiration time' do
      expect(subject.submit_time).to eq(subject.expiration_time)
    end

    it 'returns the correct submit and expiration times' do
      expect(subject.submit_time).to eq(Time.zone.now.in_time_zone('Eastern Time (US & Canada)').strftime('%I:%M %p'))
    end

    it 'returns the correct expiration date' do
      matching_time = Time.zone.now.in_time_zone('Eastern Time (US & Canada)') + 60.days
      expect(subject.expiration_date).to eq(matching_time.strftime('%B %d, %Y'))
    end

    it 'returns the correct representative name if one is supplied' do
      expect(subject.representative_name).to eq('Rep Name')
    end

    it 'returns the org name if there is no representative specified' do
      form_data_with_no_rep = build(:form_2122_data, representative_id: nil, organization_id: organization.id)
      subject = described_class.new(form_data: form_data_with_no_rep)
      expect(subject.representative_name).to eq('Org Name')
    end

    it 'returns the veterans email if there is no claimant' do
      expect(subject.email_address).to eq('veteran@example.com')
    end

    it 'returns the claimants email if there is a claimant' do
      form_data_with_claimant = build(:form_2122_data, :with_claimant, organization_id: organization.id,
                                                                       representative_id: representative.id)
      subject = described_class.new(form_data: form_data_with_claimant)
      expect(subject.email_address).to eq('claimant@example.com')
    end
  end
end
