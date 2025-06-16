# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditedEntitiesQueueUpdates, type: :job do
  subject(:job) { described_class.new }

  let(:client) { RepresentationManagement::GCLAWS::Client }
  let(:batch) { instance_double(Sidekiq::Batch) }

  before do
    allow(Rails.logger).to receive(:error)
    allow(Sidekiq::Batch).to receive(:new).and_return(batch)
    allow(batch).to receive(:description=)
    allow(batch).to receive(:jobs).and_yield
  end

  describe '#perform' do
    let(:entity_counts) { instance_double(RepresentationManagement::AccreditationApiEntityCount) }

    before do
      allow(RepresentationManagement::AccreditationApiEntityCount).to receive(:new).and_return(entity_counts)
      allow(entity_counts).to receive(:save_api_counts)
      allow(entity_counts).to receive(:valid_count?).and_return(true)

      allow(job).to receive(:update_agents)
      allow(job).to receive(:validate_agent_addresses)
      allow(job).to receive(:update_attorneys)
      allow(job).to receive(:validate_attorney_addresses)
      allow(job).to receive(:delete_old_accredited_individuals)
      allow(job).to receive(:log_error)
    end

    it 'saves API counts when not forcing updates' do
      job.perform
      expect(entity_counts).to have_received(:save_api_counts)
    end

    it 'skips saving API counts when forcing updates' do
      job.perform(['claims_agent'])
      expect(entity_counts).not_to have_received(:save_api_counts)
    end

    context 'when processing agents' do
      context 'with valid agent count' do
        before do
          allow(entity_counts).to receive(:valid_count?).with(:agents).and_return(true)
        end

        it 'updates agents and validates addresses' do
          job.perform
          expect(job).to have_received(:update_agents)
          expect(job).to have_received(:validate_agent_addresses)
        end
      end

      context 'with invalid agent count' do
        before do
          allow(entity_counts).to receive(:valid_count?).with(:agents).and_return(false)
        end

        it 'logs an error and does not update agents' do
          job.perform
          expect(job).to have_received(:log_error).with(/Agents count decreased by more than/)
          expect(job).not_to have_received(:update_agents)
        end
      end

      context 'when forcing claims_agent updates' do
        before do
          allow(entity_counts).to receive(:valid_count?).with(:agents).and_return(false)
        end

        it 'updates agents despite invalid count' do
          job.perform(['claims_agent'])
          expect(job).to have_received(:update_agents)
        end
      end
    end

    context 'when processing attorneys' do
      context 'with valid attorney count' do
        before do
          allow(entity_counts).to receive(:valid_count?).with(:attorneys).and_return(true)
        end

        it 'updates attorneys and validates addresses' do
          job.perform
          expect(job).to have_received(:update_attorneys)
          expect(job).to have_received(:validate_attorney_addresses)
        end
      end

      context 'with invalid attorney count' do
        before do
          allow(entity_counts).to receive(:valid_count?).with(:attorneys).and_return(false)
        end

        it 'logs an error and does not update attorneys' do
          job.perform
          expect(job).to have_received(:log_error).with(/Attorneys count decreased by more than/)
          expect(job).not_to have_received(:update_attorneys)
        end
      end

      context 'when forcing attorney updates' do
        before do
          allow(entity_counts).to receive(:valid_count?).with(:attorneys).and_return(false)
        end

        it 'updates attorneys despite invalid count' do
          job.perform(['attorney'])
          expect(job).to have_received(:update_attorneys)
        end
      end
    end

    context 'when updating agents' do
      let(:agent_response1) { { 'items' => [agent1, agent2] } }
      let(:agent_response2) { { 'items' => [] } }
      let(:agent1) do
        {
          'id' => '123',
          'number' => 'A123',
          'poa' => 'ABC',
          'firstName' => 'John',
          'middleName' => 'A',
          'lastName' => 'Doe',
          'workAddress1' => '123 Main St',
          'workAddress2' => 'Apt 456',
          'workAddress3' => '',
          'workZip' => '12345',
          'workCountry' => 'USA',
          'workPhoneNumber' => '555-1234',
          'workEmailAddress' => 'john@example.com'
        }
      end
      let(:agent2) do
        {
          'id' => '456',
          'number' => 'A456',
          'poa' => 'DEF',
          'firstName' => 'Jane',
          'middleName' => '',
          'lastName' => 'Smith',
          'workAddress1' => '789 Oak St',
          'workAddress2' => '',
          'workAddress3' => '',
          'workZip' => '67890',
          'workCountry' => 'USA',
          'workPhoneNumber' => '555-5678',
          'workEmailAddress' => 'jane@example.com'
        }
      end
      let(:response1) { instance_double('Response', body: agent_response1) }
      let(:response2) { instance_double('Response', body: agent_response2) }
      let(:record1) { instance_double(AccreditedIndividual, id: 1, raw_address: nil) }
      let(:record2) { instance_double(AccreditedIndividual, id: 2, raw_address: nil) }

      before do
        # Instead of mocking job.update_agents, we'll let it execute
        # and mock the dependencies it needs

        allow(client).to receive(:get_accredited_entities)
          .with(type: 'agents', page: 1)
          .and_return(response1)
        allow(client).to receive(:get_accredited_entities)
          .with(type: 'agents', page: 2)
          .and_return(response2)

        allow(AccreditedIndividual).to receive(:find_or_create_by)
          .with({ individual_type: 'claims_agent', ogc_id: '123' })
          .and_return(record1)
        allow(AccreditedIndividual).to receive(:find_or_create_by)
          .with({ individual_type: 'claims_agent', ogc_id: '456' })
          .and_return(record2)

        allow(record1).to receive(:update)
        allow(record2).to receive(:update)

        # Allow entity_counts to pass validation so update_agents gets called
        allow(entity_counts).to receive(:valid_count?).with(:agents).and_return(true)

        # We also need to allow methods called by update_agents
        allow(job).to receive(:validate_agent_addresses)
        # Any other methods called by update_agents would need to be allowed here
      end

      it 'fetches and processes agents from the client' do
        job.perform

        # Verify the client was called
        expect(client).to have_received(:get_accredited_entities).with(type: 'agents', page: 1)
        expect(client).to have_received(:get_accredited_entities).with(type: 'agents', page: 2)

        # Verify records were found/created and updated
        expect(AccreditedIndividual).to have_received(:find_or_create_by)
          .with({ individual_type: 'claims_agent', ogc_id: '123' })
        expect(AccreditedIndividual).to have_received(:find_or_create_by)
          .with({ individual_type: 'claims_agent', ogc_id: '456' })

        # Verify the records were updated
        expect(record1).to have_received(:update)
        expect(record2).to have_received(:update)
      end

      it 'calls validate_agent_addresses after processing agents' do
        job.perform
        expect(job).to have_received(:validate_agent_addresses)
      end
    end

    it 'deletes old accredited individuals' do
      job.perform
      expect(job).to have_received(:delete_old_accredited_individuals)
    end
  end

  describe '#update_attorneys' do
    let(:attorney_response1) { { 'items' => [attorney1, attorney2] } }
    let(:attorney_response2) { { 'items' => [] } }
    let(:attorney1) do
      {
        'id' => '789',
        'number' => 'B789',
        'poa' => 'GHI',
        'firstName' => 'Bob',
        'middleName' => 'C',
        'lastName' => 'Johnson',
        'workAddress1' => '321 Pine St',
        'workAddress2' => 'Suite 789',
        'workAddress3' => '',
        'workCity' => 'Anytown',
        'workState' => 'CA',
        'workZip' => '98765',
        'workNumber' => '555-9876',
        'emailAddress' => 'bob@example.com'
      }
    end
    let(:attorney2) do
      {
        'id' => '012',
        'number' => 'B012',
        'poa' => 'JKL',
        'firstName' => 'Sarah',
        'middleName' => '',
        'lastName' => 'Williams',
        'workAddress1' => '654 Elm St',
        'workAddress2' => '',
        'workAddress3' => '',
        'workCity' => 'Othertown',
        'workState' => 'NY',
        'workZip' => '54321',
        'workNumber' => '555-4321',
        'emailAddress' => 'sarah@example.com'
      }
    end
    let(:response1) { instance_double('Response', body: attorney_response1) }
    let(:response2) { instance_double('Response', body: attorney_response2) }
    let(:record1) { instance_double(AccreditedIndividual, id: 3, raw_address: nil) }
    let(:record2) { instance_double(AccreditedIndividual, id: 4, raw_address: nil) }

    before do
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'attorneys', page: 1)
        .and_return(response1)
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'attorneys', page: 2)
        .and_return(response2)

      allow(AccreditedIndividual).to receive(:find_or_create_by)
        .with({ individual_type: 'attorney', ogc_id: '789' })
        .and_return(record1)
      allow(AccreditedIndividual).to receive(:find_or_create_by)
        .with({ individual_type: 'attorney', ogc_id: '012' })
        .and_return(record2)

      allow(record1).to receive(:update)
      allow(record2).to receive(:update)

      job.instance_variable_set(:@attorney_ids, [])
      job.instance_variable_set(:@attorney_responses, [])
      job.instance_variable_set(:@attorney_json_for_address_validation, [])
    end

    it 'fetches attorneys from the client' do
      job.send(:update_attorneys)
      expect(client).to have_received(:get_accredited_entities).with(type: 'attorneys', page: 1)
      expect(client).to have_received(:get_accredited_entities).with(type: 'attorneys', page: 2)
    end

    it 'stores attorney responses' do
      job.send(:update_attorneys)
      expect(job.instance_variable_get(:@attorney_responses)).to eq([[attorney1, attorney2]])
    end

    it 'finds or creates records for each attorney' do
      job.send(:update_attorneys)
      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with({ individual_type: 'attorney', ogc_id: '789' })
      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with({ individual_type: 'attorney', ogc_id: '012' })
    end

    it 'updates records with transformed data' do
      job.send(:update_attorneys)
      expect(record1).to have_received(:update).with(hash_including(
                                                       individual_type: 'attorney',
                                                       registration_number: 'B789',
                                                       poa_code: 'GHI',
                                                       ogc_id: '789',
                                                       first_name: 'Bob',
                                                       middle_initial: 'C',
                                                       last_name: 'Johnson'
                                                     ))
      expect(record2).to have_received(:update).with(hash_including(
                                                       individual_type: 'attorney',
                                                       registration_number: 'B012',
                                                       poa_code: 'JKL',
                                                       ogc_id: '012',
                                                       first_name: 'Sarah',
                                                       middle_initial: '',
                                                       last_name: 'Williams'
                                                     ))
    end

    it 'collects attorney IDs' do
      job.send(:update_attorneys)
      expect(job.instance_variable_get(:@attorney_ids)).to eq([3, 4])
    end
  end

  describe '#delete_old_accredited_individuals' do
    let(:agent_id) { 1 }
    let(:attorney_id) { 2 }
    let(:old_record) { instance_double(AccreditedIndividual, id: 3) }
    let(:relation) { double('ActiveRecord::Relation') }

    before do
      job.instance_variable_set(:@agent_ids, [agent_id])
      job.instance_variable_set(:@attorney_ids, [attorney_id])

      allow(AccreditedIndividual).to receive(:where).and_return(relation)
      allow(relation).to receive(:not).with(id: [agent_id, attorney_id]).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(old_record)
      allow(old_record).to receive(:destroy)
      allow(job).to receive(:log_error)
    end

    it 'deletes records not in the agent or attorney ids' do
      job.send(:delete_old_accredited_individuals)
      expect(old_record).to have_received(:destroy)
    end

    context 'when an error occurs during deletion' do
      before do
        allow(old_record).to receive(:destroy).and_raise(StandardError.new('Delete error'))
      end

      it 'logs an error' do
        job.send(:delete_old_accredited_individuals)
        expect(job).to have_received(:log_error).with(/Error deleting old accredited individual with ID 3: Delete error/)
      end
    end
  end

  describe '#validate_addresses' do
    let(:records) { [{ id: 1 }, { id: 2 }, { id: 3 }] }
    let(:description) { 'Test description' }

    before do
      allow(RepresentationManagement::AccreditedIndividualsUpdate).to receive(:perform_in)
    end

    it 'sets batch description' do
      job.send(:validate_addresses, records, description)
      expect(batch).to have_received(:description=).with(description)
    end

    it 'queues jobs with individual slices' do
      job.send(:validate_addresses, records, description)
      expect(RepresentationManagement::AccreditedIndividualsUpdate).to have_received(:perform_in)
        .with(0.minutes, records.to_json)
    end

    context 'when records are empty' do
      it 'does not create a batch' do
        job.send(:validate_addresses, [], description)
        expect(batch).not_to have_received(:description=)
      end
    end

    context 'when an error occurs' do
      before do
        allow(batch).to receive(:jobs).and_raise(StandardError.new('Batch error'))
      end

      it 'logs an error' do
        job.send(:validate_addresses, records, description)
        expect(Rails.logger).to have_received(:error).with(/Error queuing address updates: Batch error/)
      end
    end
  end

  describe '#data_transform_for_agent' do
    let(:agent) do
      {
        'id' => '123',
        'number' => 'A123',
        'poa' => 'ABC',
        'firstName' => 'John',
        'middleName' => 'A',
        'lastName' => 'Doe',
        'workAddress1' => '123 Main St',
        'workAddress2' => 'Apt 456',
        'workAddress3' => '',
        'workZip' => '12345',
        'workCountry' => 'USA',
        'workPhoneNumber' => '555-1234',
        'workEmailAddress' => 'john@example.com'
      }
    end

    before do
      allow(job).to receive(:raw_address_for_agent).with(agent).and_return('raw_address')
    end

    it 'transforms agent data to the expected format' do
      result = job.send(:data_transform_for_agent, agent)
      expect(result).to include(
        individual_type: 'claims_agent',
        registration_number: 'A123',
        poa_code: 'ABC',
        ogc_id: '123',
        first_name: 'John',
        middle_initial: 'A',
        last_name: 'Doe',
        address_line1: '123 Main St',
        address_line2: 'Apt 456',
        address_line3: '',
        zip_code: '12345',
        country_code_iso3: 'USA',
        country_name: 'USA',
        phone: '555-1234',
        email: 'john@example.com',
        raw_address: 'raw_address'
      )
    end

    it 'handles empty middle name' do
      agent['middleName'] = ''
      result = job.send(:data_transform_for_agent, agent)
      expect(result[:middle_initial]).to eq('')
    end
  end

  describe '#data_transform_for_attorney' do
    let(:attorney) do
      {
        'id' => '789',
        'number' => 'B789',
        'poa' => 'GHI',
        'firstName' => 'Bob',
        'middleName' => 'C',
        'lastName' => 'Johnson',
        'workAddress1' => '321 Pine St',
        'workAddress2' => 'Suite 789',
        'workAddress3' => '',
        'workCity' => 'Anytown',
        'workState' => 'CA',
        'workZip' => '98765',
        'workNumber' => '555-9876',
        'emailAddress' => 'bob@example.com'
      }
    end

    it 'transforms attorney data to the expected format' do
      result = job.send(:data_transform_for_attorney, attorney)
      expect(result).to include(
        individual_type: 'attorney',
        registration_number: 'B789',
        poa_code: 'GHI',
        ogc_id: '789',
        first_name: 'Bob',
        middle_initial: 'C',
        last_name: 'Johnson',
        address_line1: '321 Pine St',
        address_line2: 'Suite 789',
        address_line3: '',
        city: 'Anytown',
        state_code: 'CA',
        zip_code: '98765',
        phone: '555-9876',
        email: 'bob@example.com'
      )
    end
  end
end
