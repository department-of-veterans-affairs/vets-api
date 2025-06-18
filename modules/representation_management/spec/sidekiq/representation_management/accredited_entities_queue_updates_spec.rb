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

    # Setup for external entities
    let(:agent_response) { { 'items' => [agent1] } }
    let(:empty_response) { { 'items' => [] } }
    let(:agent1) do
      {
        'id' => '123',
        'number' => 'A123',
        'poa' => 'ABC',
        'firstName' => 'John',
        'lastName' => 'Doe',
        'workAddress1' => '123 Main St',
        'workZip' => '12345',
        'workCountry' => 'USA'
      }
    end

    let(:attorney_response) { { 'items' => [attorney1] } }
    let(:attorney1) do
      {
        'id' => '789',
        'number' => 'B789',
        'poa' => 'GHI',
        'firstName' => 'Bob',
        'lastName' => 'Johnson',
        'workAddress1' => '321 Pine St',
        'workCity' => 'Anytown',
        'workState' => 'CA',
        'workZip' => '98765'
      }
    end

    let(:agent_record) { instance_double(AccreditedIndividual, id: 1, raw_address: nil) }
    let(:attorney_record) { instance_double(AccreditedIndividual, id: 2, raw_address: nil) }

    before do
      # Only stub external dependencies
      allow(RepresentationManagement::AccreditationApiEntityCount).to receive(:new).and_return(entity_counts)
      allow(entity_counts).to receive(:save_api_counts)
      allow(entity_counts).to receive(:valid_count?).with(:agents).and_return(true)
      allow(entity_counts).to receive(:valid_count?).with(:attorneys).and_return(true)

      # Mock API responses
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'agents', page: 1)
        .and_return(instance_double(Faraday::Response, body: agent_response))
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'agents', page: 2)
        .and_return(instance_double(Faraday::Response, body: empty_response))
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'attorneys', page: 1)
        .and_return(instance_double(Faraday::Response, body: attorney_response))
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'attorneys', page: 2)
        .and_return(instance_double(Faraday::Response, body: empty_response))

      # Mock record creation
      allow(AccreditedIndividual).to receive(:find_or_create_by)
        .with({ individual_type: 'claims_agent', ogc_id: '123' })
        .and_return(agent_record)
      allow(AccreditedIndividual).to receive(:find_or_create_by)
        .with({ individual_type: 'attorney', ogc_id: '789' })
        .and_return(attorney_record)

      # Mock record updates
      allow(agent_record).to receive(:update)
      allow(attorney_record).to receive(:update)
      allow(agent_record).to receive(:raw_address)
      allow(attorney_record).to receive(:raw_address)

      # Mock ActiveRecord for deletion
      relation = double('ActiveRecord::Relation')
      allow(AccreditedIndividual).to receive(:where).and_return(relation)
      allow(relation).to receive(:not).and_return(relation)
      allow(relation).to receive(:find_each)

      # Allow validation
      allow(RepresentationManagement::AccreditedIndividualsUpdate).to receive(:perform_in)
    end

    it 'processes all entity types and saves API counts' do
      job.perform

      # Verify API counts were saved
      expect(entity_counts).to have_received(:save_api_counts)

      # Verify records were created and updated
      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with(individual_type: 'claims_agent', ogc_id: '123')
      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with(individual_type: 'attorney', ogc_id: '789')
      expect(agent_record).to have_received(:update)
      expect(attorney_record).to have_received(:update)
    end

    context 'when forcing updates' do
      it 'skips saving API counts' do
        job.perform(['claims_agent'])
        expect(entity_counts).not_to have_received(:save_api_counts)
      end
    end

    context 'when agent count is invalid' do
      before do
        allow(entity_counts).to receive(:valid_count?).with(:agents).and_return(false)
      end

      it 'logs an error and skips agent updates' do
        expect(Rails.logger).to receive(:error).with(/decreased by more than/)
        job.perform

        # Verify no agents were processed
        expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
          .with(hash_including(individual_type: 'claims_agent'))
      end

      it 'still updates attorneys' do
        job.perform
        expect(AccreditedIndividual).to have_received(:find_or_create_by)
          .with(individual_type: 'attorney', ogc_id: '789')
      end

      context 'when forcing claims_agent updates' do
        it 'updates agents despite invalid count' do
          job.perform(['claims_agent'])
          expect(AccreditedIndividual).to have_received(:find_or_create_by)
            .with(individual_type: 'claims_agent', ogc_id: '123')
        end

        it 'does not update attorneys' do
          job.perform(['claims_agent'])
          expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
            .with(individual_type: 'attorney', ogc_id: '789')
        end
      end
    end

    context 'when attorney count is invalid' do
      before do
        allow(entity_counts).to receive(:valid_count?).with(:attorneys).and_return(false)
      end

      it 'logs an error and skips attorney updates' do
        expect(Rails.logger).to receive(:error).with(/decreased by more than/)
        job.perform

        # Verify no attorneys were processed
        expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
          .with(hash_including(individual_type: 'attorney'))
      end

      it 'still updates agents' do
        job.perform
        expect(AccreditedIndividual).to have_received(:find_or_create_by)
          .with(individual_type: 'claims_agent', ogc_id: '123')
      end

      context 'when forcing attorney updates' do
        it 'updates attorneys despite invalid count' do
          job.perform(['attorney'])
          expect(AccreditedIndividual).to have_received(:find_or_create_by)
            .with(individual_type: 'attorney', ogc_id: '789')
        end

        it 'does not update agents' do
          job.perform(['attorney'])
          expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
            .with(individual_type: 'claims_agent', ogc_id: '123')
        end
      end
    end
  end

  describe '#update_agents' do
    subject(:job) { described_class.new }

    let(:client) { RepresentationManagement::GCLAWS::Client }
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
    let(:response1) { instance_double(Faraday::Response, body: agent_response1) }
    let(:response2) { instance_double(Faraday::Response, body: agent_response2) }
    let(:record1) { instance_double(AccreditedIndividual, id: 1, raw_address: nil) }
    let(:record2) { instance_double(AccreditedIndividual, id: 2, raw_address: nil) }

    before do
      # Initialize instance variables that the method expects
      job.instance_variable_set(:@agent_ids, [])
      job.instance_variable_set(:@agent_responses, [])
      job.instance_variable_set(:@agent_json_for_address_validation, [])

      # Only stub external dependencies, not methods on the object under test
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'agents', page: 1)
        .and_return(response1)
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'agents', page: 2)
        .and_return(response2)

      allow(AccreditedIndividual).to receive(:find_or_create_by) do |args|
        case args[:ogc_id]
        when '123' then record1
        when '456' then record2
        else
          instance_double(AccreditedIndividual, id: SecureRandom.uuid, raw_address: nil)
        end
      end

      allow(record1).to receive(:update)
      allow(record2).to receive(:update)

      # IMPORTANT: Do NOT stub these methods as they are part of the class under test
      # Instead, let them run with their real implementation
      # NOT doing: allow(job).to receive(:raw_address_for_agent)
      # NOT doing: allow(job).to receive(:data_transform_for_agent)

      # We still need to stub the logger to avoid actual logging
      allow(Rails.logger).to receive(:error)
    end

    it 'fetches agents from the client' do
      job.send(:update_agents)

      expect(client).to have_received(:get_accredited_entities)
        .with(type: 'agents', page: 1)
      expect(client).to have_received(:get_accredited_entities)
        .with(type: 'agents', page: 2)
    end

    it 'stores agent responses' do
      job.send(:update_agents)

      expect(job.instance_variable_get(:@agent_responses))
        .to eq([[agent1, agent2]])
    end

    it 'finds or creates records for each agent' do
      job.send(:update_agents)

      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with(individual_type: 'claims_agent', ogc_id: '123')
      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with(individual_type: 'claims_agent', ogc_id: '456')
    end

    it 'updates records with transformed data' do
      job.send(:update_agents)

      # We're expecting the real data_transform_for_agent method
      # to be called with the actual implementation
      record1_attrs = {
        individual_type: 'claims_agent',
        registration_number: 'A123',
        poa_code: 'ABC',
        ogc_id: '123',
        first_name: 'John',
        middle_initial: 'A',
        last_name: 'Doe'
      }

      record2_attrs = {
        individual_type: 'claims_agent',
        registration_number: 'A456',
        poa_code: 'DEF',
        ogc_id: '456',
        first_name: 'Jane',
        last_name: 'Smith'
      }

      expect(record1).to have_received(:update)
        .with(hash_including(record1_attrs))
      expect(record2).to have_received(:update)
        .with(hash_including(record2_attrs))
    end

    it 'collects agent IDs' do
      job.send(:update_agents)
      expect(job.instance_variable_get(:@agent_ids)).to eq([1, 2])
    end

    it 'adds address validation data when address has changed' do
      # Setup a specific case where address has changed
      old_address = { 'address_line1' => 'Old Address' }
      allow(record1).to receive(:raw_address).and_return(old_address)

      job.send(:update_agents)

      # The real implementation should add to the validation array
      expect(job.instance_variable_get(:@agent_json_for_address_validation)).not_to be_empty
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
    let(:response1) { instance_double(Faraday::Response, body: attorney_response1) }
    let(:response2) { instance_double(Faraday::Response, body: attorney_response2) }
    let(:record1) { instance_double(AccreditedIndividual, id: 3, raw_address: nil) }
    let(:record2) { instance_double(AccreditedIndividual, id: 4, raw_address: nil) }

    before do
      # Initialize instance variables
      job.instance_variable_set(:@attorney_ids, [])
      job.instance_variable_set(:@attorney_responses, [])
      job.instance_variable_set(:@attorney_json_for_address_validation, [])

      # Mock external dependencies only
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'attorneys', page: 1)
        .and_return(response1)
      allow(client).to receive(:get_accredited_entities)
        .with(type: 'attorneys', page: 2)
        .and_return(response2)

      # Use flexible argument matcher for find_or_create_by
      allow(AccreditedIndividual).to receive(:find_or_create_by) do |args|
        case args[:ogc_id]
        when '789' then record1
        when '012' then record2
        else
          instance_double(AccreditedIndividual, id: SecureRandom.uuid, raw_address: nil)
        end
      end

      allow(record1).to receive(:update)
      allow(record2).to receive(:update)
      allow(record1).to receive(:raw_address)
      allow(record2).to receive(:raw_address)

      # Don't stub any methods on the job object itself
    end

    it 'fetches attorneys from the client' do
      job.send(:update_attorneys)

      expect(client).to have_received(:get_accredited_entities)
        .with(type: 'attorneys', page: 1)
      expect(client).to have_received(:get_accredited_entities)
        .with(type: 'attorneys', page: 2)
    end

    it 'stores attorney responses' do
      job.send(:update_attorneys)

      expect(job.instance_variable_get(:@attorney_responses))
        .to eq([[attorney1, attorney2]])
    end

    it 'finds or creates records for each attorney' do
      job.send(:update_attorneys)

      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with(hash_including(individual_type: 'attorney', ogc_id: '789'))
      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with(hash_including(individual_type: 'attorney', ogc_id: '012'))
    end

    it 'updates records with transformed data' do
      job.send(:update_attorneys)

      record1_attrs = {
        individual_type: 'attorney',
        registration_number: 'B789',
        poa_code: 'GHI',
        ogc_id: '789',
        first_name: 'Bob',
        middle_initial: 'C',
        last_name: 'Johnson'
      }

      record2_attrs = {
        individual_type: 'attorney',
        registration_number: 'B012',
        poa_code: 'JKL',
        ogc_id: '012',
        first_name: 'Sarah',
        middle_initial: '',
        last_name: 'Williams'
      }

      expect(record1).to have_received(:update)
        .with(hash_including(record1_attrs))
      expect(record2).to have_received(:update)
        .with(hash_including(record2_attrs))
    end

    it 'collects attorney IDs' do
      job.send(:update_attorneys)
      expect(job.instance_variable_get(:@attorney_ids)).to eq([3, 4])
    end

    it 'adds address validation data when address has changed' do
      old_address = { 'address_line1' => 'Old Address' }
      allow(record1).to receive(:raw_address).and_return(old_address)

      job.send(:update_attorneys)

      expect(job.instance_variable_get(:@attorney_json_for_address_validation))
        .not_to be_empty
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

      # Instead of stubbing the log_error method on the job,
      # stub Rails.logger which is an external dependency
      allow(Rails.logger).to receive(:error)
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

        # Expect the external dependency to be called instead
        error_text_heading = 'RepresentationManagement::AccreditedEntitiesQueueUpdates error:'
        error_text_message = 'Error deleting old accredited individual with ID 3: Delete error'
        expect(Rails.logger).to have_received(:error)
          .with("#{error_text_heading} #{error_text_message}")
      end
    end
  end

  describe '#validate_addresses' do
    let(:records) { [{ id: 1 }, { id: 2 }, { id: 3 }] }
    let(:description) { 'Test description' }

    before do
      # Only stub external dependencies
      allow(RepresentationManagement::AccreditedIndividualsUpdate).to receive(:perform_in)
      allow(Sidekiq::Batch).to receive(:new).and_return(batch)
      allow(batch).to receive(:description=)
      allow(batch).to receive(:jobs).and_yield
    end

    it 'sets batch description' do
      job.send(:validate_addresses, records, description)
      expect(batch).to have_received(:description=).with(description)
    end

    it 'queues jobs with individual slices' do
      job.send(:validate_addresses, records, description)
      expect(RepresentationManagement::AccreditedIndividualsUpdate)
        .to have_received(:perform_in)
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
        error_text_heading = 'RepresentationManagement::AccreditedEntitiesQueueUpdates error:'
        error_text_message = 'Error queuing address updates: Batch error'
        expect(Rails.logger).to receive(:error)
          .with("#{error_text_heading} #{error_text_message}")

        job.send(:validate_addresses, records, description)
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

    # No need to stub raw_address_for_agent - let the real method run
    # Instead, we'll check if the expected keys are in the result

    it 'transforms agent data to the expected format' do
      result = job.send(:data_transform_for_agent, agent)

      expected_keys = %i[
        individual_type registration_number poa_code ogc_id
        first_name middle_initial last_name address_line1
        address_line2 address_line3 zip_code country_code_iso3
        country_name phone email raw_address
      ]

      expect(result.keys).to include(*expected_keys)
      expect(result[:individual_type]).to eq('claims_agent')
      expect(result[:registration_number]).to eq('A123')
      expect(result[:poa_code]).to eq('ABC')
      expect(result[:ogc_id]).to eq('123')
      expect(result[:first_name]).to eq('John')
      expect(result[:middle_initial]).to eq('A')
      expect(result[:last_name]).to eq('Doe')
      expect(result[:raw_address]).to be_a(Hash)
      expect(result[:raw_address]['address_line1']).to eq('123 Main St')
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

      expected_keys = %i[
        individual_type registration_number poa_code ogc_id
        first_name middle_initial last_name address_line1
        address_line2 address_line3 city state_code
        zip_code phone email
      ]

      expect(result.keys).to include(*expected_keys)
      expect(result[:individual_type]).to eq('attorney')
      expect(result[:registration_number]).to eq('B789')
      expect(result[:poa_code]).to eq('GHI')
      expect(result[:ogc_id]).to eq('789')
      expect(result[:first_name]).to eq('Bob')
      expect(result[:middle_initial]).to eq('C')
      expect(result[:last_name]).to eq('Johnson')
      expect(result[:city]).to eq('Anytown')
      expect(result[:state_code]).to eq('CA')
    end

    it 'handles empty middle name' do
      attorney['middleName'] = ''
      result = job.send(:data_transform_for_attorney, attorney)
      expect(result[:middle_initial]).to eq('')
    end
  end
end
