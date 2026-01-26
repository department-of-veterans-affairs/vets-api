# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditedIndividualsUpdate do
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
      let!(:individual1) { create(:accredited_individual, raw_address: raw_address_data) }
      let!(:individual2) { create(:accredited_individual, raw_address: raw_address_data) }
      let(:record_ids) { [individual1.id, individual2.id] }

      before do
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address).and_return(true)
      end

      it 'processes all records without errors' do
        expect(Rails.logger).not_to receive(:error)
        expect { subject.perform(record_ids) }.not_to raise_error
      end

      it 'calls validate_address for each record' do
        # Spy to track calls across all instances
        call_count = 0
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address) do
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
          /RepresentationManagement::AccreditedIndividualsUpdate: Record not found: 999999/
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
      let!(:individual) { create(:accredited_individual, raw_address: raw_address_data) }
      let(:record_ids) { [individual.id, 999_999] }

      before do
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address).and_return(true)
      end

      it 'processes valid records and logs errors for invalid ones' do
        expect_any_instance_of(AccreditedIndividual).to receive(:validate_address).once
        expect(Rails.logger).to receive(:error).with(/Record not found: 999999/)
        subject.perform(record_ids)
      end
    end

    context 'when validate_address returns false' do
      let!(:individual) { create(:accredited_individual, raw_address: raw_address_data) }
      let(:record_ids) { [individual.id] }

      before do
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address).and_return(false)
      end

      it 'logs a validation failure error' do
        expect(Rails.logger).to receive(:error).with(
          /RepresentationManagement::AccreditedIndividualsUpdate: Address validation failed for record #{individual.id}/
        )
        allow(Rails.logger).to receive(:info)
        subject.perform(record_ids)
      end

      it 'enqueues a geocoding job for the failed record' do
        allow(Rails.logger).to receive(:error)
        allow(Rails.logger).to receive(:info)

        expect(RepresentationManagement::GeocodeRepresentativeJob)
          .to receive(:perform_in)
          .with(0.seconds, 'AccreditedIndividual', individual.id)

        subject.perform(record_ids)
      end
    end

    context 'when validate_address raises an exception' do
      let!(:individual) { create(:accredited_individual, raw_address: raw_address_data) }
      let(:record_ids) { [individual.id] }

      before do
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address)
          .and_raise(StandardError.new('Validation error'))
      end

      it 'logs the exception' do
        expect(Rails.logger).to receive(:error)
          .with(/Error processing record #{individual.id}: Validation error/)
        subject.perform(record_ids)
      end

      it 'adds the error to slack messages' do
        allow(Rails.logger).to receive(:error)
        subject.perform(record_ids)
        expect(subject.slack_messages).to include(/Error processing record #{individual.id}/)
      end
    end

    context 'when job execution raises an exception' do
      let(:record_ids) { [1, 2, 3] }

      before do
        allow(record_ids).to receive(:each).and_raise(StandardError.new('Job execution error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(
          /RepresentationManagement::AccreditedIndividualsUpdate: Error processing job: Job execution error/
        )
        subject.perform(record_ids)
      end

      it 'adds the error to slack messages' do
        allow(Rails.logger).to receive(:error)
        subject.perform(record_ids)
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

    context 'with duplicate record IDs' do
      let!(:individual) { create(:accredited_individual, raw_address: raw_address_data) }
      let(:record_ids) { [individual.id, individual.id] }

      before do
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address).and_return(true)
      end

      it 'handles duplicate IDs gracefully' do
        expect { subject.perform(record_ids) }.not_to raise_error
      end

      it 'processes the same record multiple times' do
        call_count = 0
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address) do
          call_count += 1
          true
        end

        subject.perform(record_ids)
        expect(call_count).to eq(2)
      end
    end

    context 'with different individual types' do
      let!(:attorney) { create(:accredited_individual, :attorney, raw_address: raw_address_data) }
      let!(:agent) { create(:accredited_individual, :claims_agent, raw_address: raw_address_data) }
      let!(:representative) { create(:accredited_individual, :representative, raw_address: raw_address_data) }
      let(:record_ids) { [attorney.id, agent.id, representative.id] }

      before do
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address).and_return(true)
      end

      it 'processes all individual types' do
        call_count = 0
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address) do
          call_count += 1
          true
        end

        subject.perform(record_ids)
        expect(call_count).to eq(3)
      end
    end

    context 'slack notifications' do
      let!(:individual1) { create(:accredited_individual, raw_address: raw_address_data) }
      let!(:individual2) { create(:accredited_individual, raw_address: raw_address_data) }
      let(:record_ids) { [individual1.id, individual2.id] }

      before do
        allow_any_instance_of(AccreditedIndividual).to receive(:validate_address)
          .and_raise(StandardError.new('Error 1'))
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'sends slack notification when there are errors' do
        allow(Rails.logger).to receive(:error)
        slack_client = double('SlackNotify::Client')
        allow(SlackNotify::Client).to receive(:new).and_return(slack_client)

        expect(slack_client).to receive(:notify) do |message|
          expect(message).to include('RepresentationManagement::AccreditedIndividualsUpdate')
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

    context 'geocoding job enqueueing' do
      context 'with multiple failed validations' do
        let!(:individual1) { create(:accredited_individual, raw_address: raw_address_data) }
        let!(:individual2) { create(:accredited_individual, raw_address: raw_address_data) }
        let!(:individual3) { create(:accredited_individual, raw_address: raw_address_data) }
        let(:record_ids) { [individual1.id, individual2.id, individual3.id] }

        before do
          allow_any_instance_of(AccreditedIndividual).to receive(:validate_address).and_return(false)
          allow(Rails.logger).to receive(:error)
          allow(Rails.logger).to receive(:info)
        end

        it 'enqueues jobs with 2-second spacing' do
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(0.seconds, 'AccreditedIndividual', individual1.id)
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(2.seconds, 'AccreditedIndividual', individual2.id)
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(4.seconds, 'AccreditedIndividual', individual3.id)

          subject.perform(record_ids)
        end
      end

      context 'with mixed success and failure validations' do
        let!(:individual1) { create(:accredited_individual, raw_address: raw_address_data) }
        let!(:individual2) { create(:accredited_individual, raw_address: raw_address_data) }
        let!(:individual3) { create(:accredited_individual, raw_address: raw_address_data) }
        let(:record_ids) { [individual1.id, individual2.id, individual3.id] }

        before do
          allow(Rails.logger).to receive(:error)
          allow(Rails.logger).to receive(:info)

          # Only individual2 fails validation
          allow(individual1).to receive(:validate_address).and_return(true)
          allow(individual2).to receive(:validate_address).and_return(false)
          allow(individual3).to receive(:validate_address).and_return(true)

          allow(AccreditedIndividual).to receive(:find_by).with(id: individual1.id).and_return(individual1)
          allow(AccreditedIndividual).to receive(:find_by).with(id: individual2.id).and_return(individual2)
          allow(AccreditedIndividual).to receive(:find_by).with(id: individual3.id).and_return(individual3)
        end

        it 'only enqueues geocoding jobs for failed validations' do
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).once
            .with(0.seconds, 'AccreditedIndividual', individual2.id)

          subject.perform(record_ids)
        end
      end

      context 'when all validations succeed' do
        let!(:individual1) { create(:accredited_individual, raw_address: raw_address_data) }
        let!(:individual2) { create(:accredited_individual, raw_address: raw_address_data) }
        let(:record_ids) { [individual1.id, individual2.id] }

        before do
          allow_any_instance_of(AccreditedIndividual).to receive(:validate_address).and_return(true)
        end

        it 'does not enqueue any geocoding jobs' do
          expect(RepresentationManagement::GeocodeRepresentativeJob).not_to receive(:perform_in)

          subject.perform(record_ids)
        end

        it 'does not log geocoding job count' do
          expect(Rails.logger).not_to receive(:info).with(/Enqueued.*geocoding jobs/)

          subject.perform(record_ids)
        end
      end

      context 'with different individual types needing geocoding' do
        let!(:attorney) { create(:accredited_individual, :attorney, raw_address: raw_address_data) }
        let!(:agent) { create(:accredited_individual, :claims_agent, raw_address: raw_address_data) }
        let!(:representative) { create(:accredited_individual, :representative, raw_address: raw_address_data) }
        let(:record_ids) { [attorney.id, agent.id, representative.id] }

        before do
          allow_any_instance_of(AccreditedIndividual).to receive(:validate_address).and_return(false)
          allow(Rails.logger).to receive(:error)
          allow(Rails.logger).to receive(:info)
        end

        it 'enqueues geocoding jobs for all individual types' do
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(0.seconds, 'AccreditedIndividual', attorney.id)
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(2.seconds, 'AccreditedIndividual', agent.id)
          expect(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).with(4.seconds, 'AccreditedIndividual', representative.id)

          subject.perform(record_ids)
        end
      end

      context 'when geocoding job enqueueing fails' do
        let!(:individual) { create(:accredited_individual, raw_address: raw_address_data) }
        let(:record_ids) { [individual.id] }

        before do
          allow_any_instance_of(AccreditedIndividual).to receive(:validate_address).and_return(false)
          allow(Rails.logger).to receive(:error)
          allow(RepresentationManagement::GeocodeRepresentativeJob)
            .to receive(:perform_in).and_raise(StandardError.new('Sidekiq error'))
        end

        it 'logs the error' do
          expect(Rails.logger).to receive(:error).with(
            /RepresentationManagement::AccreditedIndividualsUpdate: Error enqueueing geocoding jobs: Sidekiq error/
          )

          subject.perform(record_ids)
        end

        it 'adds the error to slack messages' do
          subject.perform(record_ids)
          expect(subject.slack_messages).to include(/Error enqueueing geocoding jobs/)
        end
      end
    end

    context 'integration with AccreditedIndividual#validate_address' do
      let!(:individual) { create(:accredited_individual, raw_address: raw_address_data) }
      let(:record_ids) { [individual.id] }
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
        individual.reload

        expect(individual.lat).to eq(40.717029)
        expect(individual.long).to eq(-73.964956)
      end
    end
  end
end
