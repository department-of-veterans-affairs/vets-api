# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::EmailPersonalisations do
  describe '.generate' do
    let(:notification) { create(:power_of_attorney_request_notification, type:) }

    context 'when type is requested' do
      let(:type) { 'requested' }
      let(:organization) { create(:organization, name: 'Org Name') }

      it 'returns the full hash for the digital submit confirmation email' do
        notification.power_of_attorney_request.power_of_attorney_holder_poa_code = organization.poa
        expiration_date = (Time.zone.now.in_time_zone('Eastern Time (US & Canada)') + 60.days).strftime('%B %d, %Y')
        rep_name = notification.accredited_individual.full_name.strip
        org_name = notification.accredited_organization.name.strip
        expected_hash = {
          'first_name' => notification.claimant_hash['name']['first'],
          'last_name' => notification.claimant_hash['name']['last'],
          'submit_date' => Time.zone.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y'),
          'expiration_date' => expiration_date,
          'representative_name' => "#{rep_name} accredited with #{org_name}"
        }
        expect(described_class::Requested.new(notification).generate).to eq(expected_hash)
      end
    end

    context 'when type is declined' do
      let(:type) { 'declined' }

      it 'returns a hash with the first name' do
        expected_hash = { 'first_name' => notification.claimant_hash['name']['first'] }
        expect(described_class::Declined.new(notification).generate).to eq(expected_hash)
      end
    end

    context 'when type is expiring' do
      let(:type) { 'expiring' }

      it 'returns a hash with the first name' do
        expected_hash = { 'first_name' => notification.claimant_hash['name']['first'] }
        expect(described_class::Expiring.new(notification).generate).to eq(expected_hash)
      end
    end

    context 'when type is expired' do
      let(:type) { 'expired' }

      it 'returns a hash with the first name' do
        expected_hash = { 'first_name' => notification.claimant_hash['name']['first'] }
        expect(described_class::Expired.new(notification).generate).to eq(expected_hash)
      end
    end
  end

  describe 'Requested subclass' do
    let(:notification) { create(:power_of_attorney_request_notification, type: 'requested') }
    let(:organization) { create(:organization, name: 'Org Name') }
    let(:personalisation) { described_class::Requested.new(notification) }

    it 'returns the submit date' do
      expected_date = Time.zone.now.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y')
      expect(personalisation.send(:submit_date)).to eq(expected_date)
    end

    it 'returns the expiration date' do
      expected_date = (Time.zone.now.in_time_zone('Eastern Time (US & Canada)') + 60.days).strftime('%B %d, %Y')
      expect(personalisation.send(:expiration_date)).to eq(expected_date)
    end

    it 'returns the representative name' do
      notification.power_of_attorney_request.power_of_attorney_holder_poa_code = organization.poa
      accredited_individual_name = notification.accredited_individual.full_name.strip
      accredited_organization_name = notification.accredited_organization.name.strip
      expected_name = "#{accredited_individual_name} accredited with #{accredited_organization_name}"
      expect(personalisation.send(:representative_name)).to eq(expected_name)
    end
  end
end
