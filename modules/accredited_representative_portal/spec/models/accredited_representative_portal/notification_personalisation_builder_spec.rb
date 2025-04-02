# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::NotificationPersonalisationBuilder, type: :model do
  let(:power_of_attorney_request) { create(:power_of_attorney_request) }
  let(:va_notify_notification) { create(:notification) }

  describe '#build' do
    let(:notification) { create(:power_of_attorney_request_notification, type:) }
    let(:personalisation_builder) { described_class.new(notification) }

    context 'when type is declined' do
      let(:type) { 'declined' }

      it 'returns a hash with the first name' do
        expect(personalisation_builder.build).to eq('first_name' => personalisation_builder.first_name)
      end
    end

    context 'when type is expiring' do
      let(:type) { 'expiring' }

      it 'returns a hash with the first name' do
        expect(personalisation_builder.build).to eq('first_name' => personalisation_builder.first_name)
      end
    end

    context 'when type is expired' do
      let(:type) { 'expired' }

      it 'returns a hash with the first name' do
        expect(personalisation_builder.build).to eq('first_name' => personalisation_builder.first_name)
      end
    end

    context 'when type is requested' do
      let(:type) { 'requested' }

      it 'returns the full hash for the digital submit confirmation email' do
        expected_hash = {
          'first_name' => personalisation_builder.first_name,
          'last_name' => personalisation_builder.last_name,
          'submit_date' => personalisation_builder.submit_date,
          'expiration_date' => personalisation_builder.expiration_date,
          'representative_name' => personalisation_builder.representative_name
        }
        expect(personalisation_builder.build).to eq(expected_hash)
      end
    end
  end

  describe 'dates' do
    let(:notification) { create(:power_of_attorney_request_notification) }
    let(:personalisation_builder) { described_class.new(notification) }

    it 'returns the submit date' do
      time_zone = 'Eastern Time (US & Canada)'
      expect(personalisation_builder.submit_date).to eq(Time.zone.now.in_time_zone(time_zone).strftime('%B %d, %Y'))
    end

    it 'returns the expiration date' do
      matching_time = Time.zone.now.in_time_zone('Eastern Time (US & Canada)') + 60.days
      expect(personalisation_builder.expiration_date).to eq(matching_time.strftime('%B %d, %Y'))
    end
  end

  describe '#representative_name' do
    let(:representative) { create(:representative, first_name: 'Rep', last_name: 'Name') }
    let(:organization) { create(:organization, name: 'Org Name') }

    context 'when accredited_individual and accredited_organization are present' do
      it 'returns the full name of the individual and the name of the organization' do
        poa_request = create(:power_of_attorney_request,
                             accredited_individual_registration_number: representative.representative_id)
        poa_request.power_of_attorney_holder_poa_code = organization.poa
        notification = create(:power_of_attorney_request_notification, power_of_attorney_request: poa_request)
        personalisation_builder = described_class.new(notification)
        accredited_individual_name = notification.accredited_individual.full_name.strip
        accredited_organization_name = notification.accredited_organization.name.strip
        expect(personalisation_builder.representative_name).to eq(
          "#{accredited_individual_name} accredited with #{accredited_organization_name}"
        )
      end
    end

    context 'when accredited_individual is present' do
      it 'returns the full name of the individual' do
        poa_request = create(:power_of_attorney_request,
                             accredited_individual_registration_number: representative.representative_id)
        notification = create(:power_of_attorney_request_notification,
                              power_of_attorney_request: poa_request)
        personalisation_builder = described_class.new(notification)
        expect(personalisation_builder.representative_name).to eq(notification.accredited_individual.full_name.strip)
      end
    end

    context 'when accredited_organization is present' do
      it 'returns the name of the organization' do
        poa_request = create(:power_of_attorney_request)
        poa_request.power_of_attorney_holder_poa_code = organization.poa
        poa_request.accredited_individual_registration_number = nil
        notification = create(:power_of_attorney_request_notification, power_of_attorney_request: poa_request)
        personalisation_builder = described_class.new(notification)
        expect(personalisation_builder.representative_name).to eq(notification.accredited_organization.name.strip)
      end
    end
  end
end
