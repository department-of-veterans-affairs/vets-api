# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditedOrganizationsUpdate do
  describe '#perform' do
    let(:raw_address_data) do
      {
        'address_line1' => '123 Main St',
        'address_line2' => 'Suite 100',
        'city' => 'Brooklyn',
        'state_code' => 'NY',
        'zip_code' => '11249'
      }
    end

    context 'with valid record IDs' do
      let!(:org1) { create(:accredited_organization, raw_address: raw_address_data) }
      let!(:org2) { create(:accredited_organization, raw_address: raw_address_data) }
      let(:record_ids) { [org1.id, org2.id] }

      before do
        allow_any_instance_of(AccreditedOrganization).to receive(:validate_address).and_return(true)
      end

      it 'processes all records without errors' do
        expect(Rails.logger).not_to receive(:error)
        expect { subject.perform(record_ids) }.not_to raise_error
      end

      it 'calls validate_address for each record' do
        call_count = 0
        allow_any_instance_of(AccreditedOrganization).to receive(:validate_address) do
          call_count += 1
          true
        end

        subject.perform(record_ids)
        expect(call_count).to eq(2)
      end
    end

    context 'with non-existent record ID' do
      let(:record_ids) { [999_999] }

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(
          /RepresentationManagement::AccreditedOrganizationsUpdate: Record not found: 999999/
        )
        subject.perform(record_ids)
      end

      it 'does not add to slack messages' do
        allow(Rails.logger).to receive(:error)
        subject.perform(record_ids)
        expect(subject.slack_messages).to be_empty
      end
    end

    context 'with mixed valid and invalid IDs' do
      let!(:organization) { create(:accredited_organization, raw_address: raw_address_data) }
      let(:record_ids) { [organization.id, 999_999] }

      before do
        allow_any_instance_of(AccreditedOrganization).to receive(:validate_address).and_return(true)
      end

      it 'processes valid records and logs errors for invalid ones' do
        expect_any_instance_of(AccreditedOrganization).to receive(:validate_address).once
        expect(Rails.logger).to receive(:error).with(/Record not found: 999999/)
        subject.perform(record_ids)
      end
    end

    context 'when validate_address returns false' do
      let!(:organization) { create(:accredited_organization, raw_address: raw_address_data) }
      let(:record_ids) { [organization.id] }

      before do
        allow_any_instance_of(AccreditedOrganization).to receive(:validate_address).and_return(false)
      end

      it 'logs a validation failure error' do
        expect(Rails.logger).to receive(:error).with(
          /Address validation failed for record #{organization.id}/
        )
        allow(Rails.logger).to receive(:info)
        subject.perform(record_ids)
      end

      it 'enqueues a geocoding job for the failed record' do
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)

        expect(RepresentationManagement::GeocodeRepresentativeJob)
          .to receive(:perform_in)
          .with(0.seconds, 'AccreditedOrganization', organization.id)

        subject.perform(record_ids)
      end
    end

    context 'when validate_address raises an exception' do
      let!(:organization) { create(:accredited_organization, raw_address: raw_address_data) }
      let(:record_ids) { [organization.id] }

      before do
        allow_any_instance_of(AccreditedOrganization).to receive(:validate_address)
          .and_raise(StandardError.new('Validation error'))
      end

      it 'logs the exception' do
        expect(Rails.logger).to receive(:error)
          .with(/Error processing record #{organization.id}: Validation error/)
        subject.perform(record_ids)
      end

      it 'adds the error to slack messages' do
        allow(Rails.logger).to receive(:error)
        subject.perform(record_ids)
        expect(subject.slack_messages).to include(/Error processing record #{organization.id}/)
      end
    end

    context 'when job execution raises an exception' do
      let(:record_ids) { [1, 2, 3] }

      before do
        allow(record_ids).to receive(:each).and_raise(StandardError.new('Job execution error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(
          /RepresentationManagement::AccreditedOrganizationsUpdate: Error processing job: Job execution error/
        )
        expect { subject.perform(record_ids) }.to raise_error(StandardError, 'Job execution error')
      end

      it 'adds the error to slack messages' do
        allow(Rails.logger).to receive(:error)
        expect { subject.perform(record_ids) }.to raise_error(StandardError)
        expect(subject.slack_messages).to include(/Error processing job/)
      end
    end

    context 'with empty array' do
      let(:record_ids) { [] }

      it 'completes without errors' do
        expect(Rails.logger).not_to receive(:error)
        expect { subject.perform(record_ids) }.not_to raise_error
      end
    end

    context 'geocoding job enqueueing' do
      context 'with multiple failed validations' do
        let!(:org1) { create(:accredited_organization, raw_address: raw_address_data) }
        let!(:org2) { create(:accredited_organization, raw_address: raw_address_data) }
        let!(:org3) { create(:accredited_organization, raw_address: raw_address_data) }
        let(:record_ids) { [org1.id, org2.id, org3.id] }

        before do
          allow_any_instance_of(AccreditedOrganization).to receive(:validate_address).and_return(false)
          allow(Rails.logger).to receive(:error)
          allow(Rails.logger).to receive(:info)
        end

        it 'enqueues jobs with 2-second spacing' do
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(0.seconds, 'AccreditedOrganization', org1.id)
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(2.seconds, 'AccreditedOrganization', org2.id)
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(4.seconds, 'AccreditedOrganization', org3.id)

          subject.perform(record_ids)
        end
      end

      context 'when all validations succeed' do
        let!(:org1) { create(:accredited_organization, raw_address: raw_address_data) }
        let!(:org2) { create(:accredited_organization, raw_address: raw_address_data) }
        let(:record_ids) { [org1.id, org2.id] }

        before do
          allow_any_instance_of(AccreditedOrganization).to receive(:validate_address).and_return(true)
        end

        it 'does not enqueue any geocoding jobs' do
          expect(RepresentationManagement::GeocodeRepresentativeJob).not_to receive(:perform_in)

          subject.perform(record_ids)
        end
      end

      context 'when geocoding job enqueueing fails' do
        let!(:organization) { create(:accredited_organization, raw_address: raw_address_data) }
        let(:record_ids) { [organization.id] }

        before do
          allow_any_instance_of(AccreditedOrganization).to receive(:validate_address).and_return(false)
          allow(Rails.logger).to receive(:error)
          allow(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).and_raise(StandardError.new('Sidekiq error'))
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(
            /RepresentationManagement::AccreditedOrganizationsUpdate: Error enqueueing geocoding jobs: Sidekiq error/
          )

          subject.perform(record_ids)
        end

        it 'adds the error to slack messages' do
          subject.perform(record_ids)
          expect(subject.slack_messages).to include(/Error enqueueing geocoding jobs/)
        end
      end
    end

    context 'slack notifications' do
      let!(:org1) { create(:accredited_organization, raw_address: raw_address_data) }
      let!(:org2) { create(:accredited_organization, raw_address: raw_address_data) }
      let(:record_ids) { [org1.id, org2.id] }

      before do
        allow_any_instance_of(AccreditedOrganization).to receive(:validate_address)
          .and_raise(StandardError.new('Error 1'))
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'sends slack notification when there are errors in production' do
        allow(Rails.logger).to receive(:error)
        slack_client = double('SlackNotify::Client')
        allow(SlackNotify::Client).to receive(:new).and_return(slack_client)

        expect(slack_client).to receive(:notify) do |message|
          expect(message).to include('RepresentationManagement::AccreditedOrganizationsUpdate')
          expect(message).to include('Error processing record')
        end

        subject.perform(record_ids)
      end

      it 'does not send slack notification in non-production' do
        allow(Settings).to receive(:vsp_environment).and_return('development')
        allow(Rails.logger).to receive(:error)

        expect(SlackNotify::Client).not_to receive(:new)

        subject.perform(record_ids)
      end
    end

    context 'integration with AccreditedOrganization#validate_address' do
      let!(:organization) { create(:accredited_organization, raw_address: raw_address_data) }
      let(:record_ids) { [organization.id] }
      let(:mock_service) { instance_double(RepresentationManagement::AddressValidationService) }
      let(:validated_attributes) do
        {
          address_line1: '123 Main St',
          city: 'Brooklyn',
          state_code: 'NY',
          lat: 40.717029,
          long: -73.964956,
          location: 'POINT(-73.964956 40.717029)'
        }
      end

      before do
        allow(RepresentationManagement::AddressValidationService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:validate_address).and_return(validated_attributes)
      end

      it 'actually updates the record through the model method' do
        subject.perform(record_ids)
        organization.reload

        expect(organization.lat).to eq(40.717029)
        expect(organization.long).to eq(-73.964956)
      end
    end
  end
end
