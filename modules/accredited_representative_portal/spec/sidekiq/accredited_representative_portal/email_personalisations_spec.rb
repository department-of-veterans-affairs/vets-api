# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::EmailPersonalisations do
  describe '.generate' do
    context 'when type is requested' do
      let(:type) { 'requested' }
      let(:notification) { create(:power_of_attorney_request_notification, type:) }
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
      
      let(:notification) { instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestNotification) }
      
      before do
        allow(notification).to receive(:claimant_hash).and_return({
          'name' => { 'first' => 'John', 'last' => 'Doe' }
        })
        
        poa_request = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequest)
        allow(notification).to receive(:power_of_attorney_request).and_return(poa_request)
        
        form = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyForm)
        allow(poa_request).to receive(:power_of_attorney_form).and_return(form)
        allow(form).to receive(:parsed_data).and_return({
          'veteran' => { 'name' => { 'first' => 'John', 'last' => 'Doe' } }
        })
        
        resolution = instance_double(AccreditedRepresentativePortal::PowerOfAttorneyRequestResolution)
        allow(poa_request).to receive(:resolution).and_return(resolution)

        decision = instance_double(
          AccreditedRepresentativePortal::PowerOfAttorneyRequestDecision, 
          declination_reason: declination_reason,
          declination_reason_text: declination_reason_text
        )
        allow(resolution).to receive(:resolving).and_return(decision)
      end

      context 'with reason DECLINATION_HEALTH_RECORDS_WITHHELD' do
        let(:declination_reason) { :HEALTH_RECORDS_WITHHELD }
        let(:declination_reason_text) { 'you didn\'t provide access to health records' }

        it 'returns the correct declination text' do
          expected_hash = {
            'first_name' => 'John',
            'declination_text' => 'The reason given was you didn\'t provide access to health records'
          }
          expect(described_class::Declined.new(notification).generate).to eq(expected_hash)
        end
      end

      context 'with reason DECLINATION_NOT_ACCEPTING_CLIENTS' do
        let(:declination_reason) { :NOT_ACCEPTING_CLIENTS }
        let(:declination_reason_text) { 'the VSO is not currently accepting new clients' }

        it 'returns the correct declination text' do
          expected_hash = {
            'first_name' => 'John',
            'declination_text' => 'The reason given was the VSO is not currently accepting new clients'
          }
          expect(described_class::Declined.new(notification).generate).to eq(expected_hash)
        end
      end

      context 'with reason DECLINATION_OTHER' do
        let(:declination_reason) { :OTHER }
        let(:declination_reason_text) { 'some other reason' }

        it 'returns an empty declination text' do
          expected_hash = {
            'first_name' => 'John',
            'declination_text' => ''
          }
          expect(described_class::Declined.new(notification).generate).to eq(expected_hash)
        end
      end

      context 'with unknown declination reason' do
        let(:declination_reason) { :SOMETHING_NEW }
        let(:declination_reason_text) { nil }

        it 'returns the base text with nil appended' do
          expected_hash = {
            'first_name' => 'John',
            'declination_text' => 'The reason given was '
          }
          expect(described_class::Declined.new(notification).generate).to eq(expected_hash)
        end
      end
    end

    context 'when type is expiring' do
      let(:type) { 'expiring' }
      let(:notification) { create(:power_of_attorney_request_notification, type:) }

      it 'returns a hash with the first name' do
        expected_hash = { 'first_name' => notification.claimant_hash['name']['first'] }
        expect(described_class::Expiring.new(notification).generate).to eq(expected_hash)
      end
    end

    context 'when type is expired' do
      let(:type) { 'expired' }
      let(:notification) { create(:power_of_attorney_request_notification, type:) }

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
