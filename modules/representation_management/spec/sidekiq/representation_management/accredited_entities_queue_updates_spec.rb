# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditedEntitiesQueueUpdates, type: :job do
  include ActiveSupport::Testing::TimeHelpers
  subject(:job) { described_class.new }

  let(:client) { RepresentationManagement::GCLAWS::Client }
  let(:batch) { instance_double(Sidekiq::Batch) }

  before do
    allow(Rails.logger).to receive(:error)
    allow(Sidekiq::Batch).to receive(:new).and_return(batch)
    allow(batch).to receive(:description=)
    allow(batch).to receive(:jobs).and_yield
    slack_client = instance_double(SlackNotify::Client)
    allow(SlackNotify::Client).to receive(:new).and_return(slack_client)
    allow(slack_client).to receive(:notify)
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
      allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::AGENTS).and_return(true)
      allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::ATTORNEYS).and_return(true)
      allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::REPRESENTATIVES).and_return(true)
      allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::VSOS).and_return(true)
      allow(entity_counts).to receive(:count_report).and_return('Count report generated successfully')

      # Mock API responses
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::AGENTS, page: 1)
        .and_return(instance_double(Faraday::Response, body: agent_response))
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::AGENTS, page: 2)
        .and_return(instance_double(Faraday::Response, body: empty_response))
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::ATTORNEYS, page: 1)
        .and_return(instance_double(Faraday::Response, body: attorney_response))
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::ATTORNEYS, page: 2)
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

      # Mock VSO and Representative API responses
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::VSOS, page: 1)
        .and_return(instance_double(Faraday::Response, body: empty_response))
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::REPRESENTATIVES, page: 1)
        .and_return(instance_double(Faraday::Response, body: empty_response))

      # Mock deletion for organizations and accreditations
      org_relation = double('ActiveRecord::Relation')
      allow(AccreditedOrganization).to receive(:where).and_return(org_relation)
      allow(org_relation).to receive(:not).and_return(org_relation)
      allow(org_relation).to receive(:find_each)

      acc_relation = double('ActiveRecord::Relation')
      allow(Accreditation).to receive(:where).and_return(acc_relation)
      allow(acc_relation).to receive(:not).and_return(acc_relation)
      allow(acc_relation).to receive(:find_each)

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
        job.perform([RepresentationManagement::AGENTS])
        expect(entity_counts).not_to have_received(:save_api_counts)
      end
    end

    context 'when agent count is invalid' do
      before do
        allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::AGENTS).and_return(false)
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
          job.perform([RepresentationManagement::AGENTS])
          expect(AccreditedIndividual).to have_received(:find_or_create_by)
            .with(individual_type: 'claims_agent', ogc_id: '123')
        end

        it 'does not update attorneys' do
          job.perform([RepresentationManagement::AGENTS])
          expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
            .with(individual_type: 'attorney', ogc_id: '789')
        end
      end
    end

    context 'when attorney count is invalid' do
      before do
        allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::ATTORNEYS).and_return(false)
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
          job.perform([RepresentationManagement::ATTORNEYS])
          expect(AccreditedIndividual).to have_received(:find_or_create_by)
            .with(individual_type: 'attorney', ogc_id: '789')
        end

        it 'does not update agents' do
          job.perform([RepresentationManagement::ATTORNEYS])
          expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
            .with(individual_type: 'claims_agent', ogc_id: '123')
        end
      end
    end

    context 'when both counts are invalid' do
      before do
        allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::AGENTS).and_return(false)
        allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::ATTORNEYS).and_return(false)
      end

      it 'logs errors for both counts and skips updates' do
        expect(Rails.logger).to receive(:error).with(/decreased by more than/).twice
        job.perform

        # Verify no records were processed
        expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
          .with(individual_type: 'claims_agent', ogc_id: '123')
        expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
          .with(individual_type: 'attorney', ogc_id: '789')
      end
    end
  end

  describe '#update_agents' do
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
      job.instance_variable_set(:@agent_json_for_address_validation, [])

      # Only stub external dependencies, not methods on the object under test
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::AGENTS, page: 1)
        .and_return(response1)
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::AGENTS, page: 2)
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
        .with(type: RepresentationManagement::AGENTS, page: 1)
      expect(client).to have_received(:get_accredited_entities)
        .with(type: RepresentationManagement::AGENTS, page: 2)
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

    it 'tracks agent IDs for deletion' do
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
      job.instance_variable_set(:@attorney_json_for_address_validation, [])

      # Mock external dependencies only
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::ATTORNEYS, page: 1)
        .and_return(response1)
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::ATTORNEYS, page: 2)
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
        .with(type: RepresentationManagement::ATTORNEYS, page: 1)
      expect(client).to have_received(:get_accredited_entities)
        .with(type: RepresentationManagement::ATTORNEYS, page: 2)
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

    it 'tracks attorney IDs for deletion' do
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

  describe '#delete_removed_accredited_individuals' do
    let(:agent_id) { 1 }
    let(:attorney_id) { 2 }
    let(:old_record) { instance_double(AccreditedIndividual, id: 3) }
    let(:relation) { double('ActiveRecord::Relation') }

    before do
      job.instance_variable_set(:@agent_ids, [agent_id])
      job.instance_variable_set(:@attorney_ids, [attorney_id])
      job.instance_variable_set(:@representative_ids, [])

      allow(AccreditedIndividual).to receive(:where).and_return(relation)
      allow(relation).to receive(:not).with(id: [agent_id, attorney_id]).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(old_record)
      allow(old_record).to receive(:destroy)

      # Instead of stubbing the log_error method on the job,
      # stub Rails.logger which is an external dependency
      allow(Rails.logger).to receive(:error)
    end

    it 'deletes records not in the agent or attorney ids' do
      job.send(:delete_removed_accredited_individuals)
      expect(old_record).to have_received(:destroy)
    end

    context 'when an error occurs during deletion' do
      before do
        allow(old_record).to receive(:destroy).and_raise(StandardError.new('Delete error'))
      end

      it 'logs an error' do
        job.send(:delete_removed_accredited_individuals)

        # Expect the external dependency to be called instead
        error_text_heading = 'RepresentationManagement::AccreditedEntitiesQueueUpdates error:'
        error_text_message = 'Error deleting old accredited individual with ID 3: Delete error'
        expect(Rails.logger).to have_received(:error)
          .with("#{error_text_heading} #{error_text_message}")
      end
    end
  end

  describe '#validate_agent_addresses' do
    before do
      # Set up the instance variable that the method will use
      agent_data = [
        { id: 1, address: { address_line1: '123 Main St' } },
        { id: 2, address: { address_line1: '456 Oak Ave' } }
      ]
      job.instance_variable_set(:@agent_json_for_address_validation, agent_data)
    end

    it 'queues address validation jobs for agents' do
      # Verify that the job is scheduled with the correct parameters
      expect(RepresentationManagement::AccreditedIndividualsUpdate).to receive(:perform_in)
        .with(0.minutes, job.instance_variable_get(:@agent_json_for_address_validation).to_json)

      # Call the method
      job.send(:validate_agent_addresses)
    end

    it 'sets the batch description to agent-specific text' do
      # Verify the batch gets the right description
      expect(batch).to receive(:description=)
        .with('Batching agent address updates from GCLAWS Accreditation API')

      job.send(:validate_agent_addresses)
    end

    it 'does nothing when there are no agent addresses to validate' do
      job.instance_variable_set(:@agent_json_for_address_validation, [])

      # Should not create a batch
      expect(Sidekiq::Batch).not_to receive(:new)

      job.send(:validate_agent_addresses)
    end
  end

  describe '#validate_attorney_addresses' do
    before do
      # Set up the instance variable that the method will use
      attorney_data = [
        { id: 3, address: { address_line1: '789 Pine St', city: 'Anytown' } },
        { id: 4, address: { address_line1: '321 Elm St', city: 'Somewhere' } }
      ]
      job.instance_variable_set(:@attorney_json_for_address_validation, attorney_data)
    end

    it 'queues address validation jobs for attorneys' do
      # Verify that the job is scheduled with the correct parameters
      expect(RepresentationManagement::AccreditedIndividualsUpdate).to receive(:perform_in)
        .with(0.minutes, job.instance_variable_get(:@attorney_json_for_address_validation).to_json)

      # Call the method
      job.send(:validate_attorney_addresses)
    end

    it 'sets the batch description to attorney-specific text' do
      # Verify the batch gets the right description
      expect(batch).to receive(:description=)
        .with('Batching attorney address updates from GCLAWS Accreditation API')

      job.send(:validate_attorney_addresses)
    end

    it 'does nothing when there are no attorney addresses to validate' do
      job.instance_variable_set(:@attorney_json_for_address_validation, [])

      # Should not create a batch
      expect(Sidekiq::Batch).not_to receive(:new)

      job.send(:validate_attorney_addresses)
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
        zip_code phone email raw_address
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
      expect(result[:raw_address]).to be_a(Hash)
      expect(result[:raw_address]['address_line1']).to eq('321 Pine St')
    end

    it 'handles empty middle name' do
      attorney['middleName'] = ''
      result = job.send(:data_transform_for_attorney, attorney)
      expect(result[:middle_initial]).to eq('')
    end
  end

  describe '#process_orgs_and_reps' do
    let(:vso_response) { { 'items' => [vso1] } }
    let(:rep_response) { { 'items' => [rep1] } }
    let(:empty_response) { { 'items' => [] } }

    let(:vso1) do
      {
        'vsoid' => '9c6f8595-4e84-42e5-b90a-270c422c373a',
        'number' => 210,
        'acceptsElectronicPoas' => false,
        'poa' => 'JQ8',
        'organization' => { 'id' => '09901a71-a3ce-4a85-a5bd-172cce0b6439', 'text' => 'Less Law Firm' }
      }
    end

    let(:rep1) do
      {
        'id' => 'ea154c64-bf20-47e0-9866-86ae988776a8',
        'representative' => {
          'lastName' => 'aalaam',
          'middleName' => '',
          'firstName' => 'judy',
          'workNumber' => '555-1234',
          'workEmailAddress' => 'judy@example.com',
          'id' => 'dfc36f35-0464-450f-a85b-3fa639705826'
        },
        'veteransServiceOrganization' => {
          'name' => 'Less Law Firm',
          'poa' => 'JQ8',
          'number' => 210,
          'id' => '9c6f8595-4e84-42e5-b90a-270c422c373a'
        },
        'lastName' => 'aalaam',
        'firstName' => 'judy',
        'middleName' => '',
        'workAddress1' => '123 Work St',
        'workAddress2' => '',
        'workAddress3' => '',
        'workCity' => 'Work City',
        'workState' => 'CA',
        'workZip' => '12345'
      }
    end

    let(:entity_counts) { instance_double(RepresentationManagement::AccreditationApiEntityCount) }
    let(:vso_record) { instance_double(AccreditedOrganization, id: 100) }
    let(:rep_record) { instance_double(AccreditedIndividual, id: 200, raw_address: nil) }
    let(:accreditation_record) { instance_double(Accreditation, id: 300) }

    before do
      job.instance_variable_set(:@entity_counts, entity_counts)
      job.instance_variable_set(:@force_update_types, [])
      job.instance_variable_set(:@vso_ids, [])
      job.instance_variable_set(:@representative_ids, [])
      job.instance_variable_set(:@representative_json_for_address_validation, [])
      job.instance_variable_set(:@rep_to_vso_associations, {})
      job.instance_variable_set(:@accreditation_ids, [])
      job.instance_variable_set(:@report, String.new)

      allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::REPRESENTATIVES).and_return(true)
      allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::VSOS).and_return(true)

      # Mock VSO API responses
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::VSOS, page: 1)
        .and_return(instance_double(Faraday::Response, body: vso_response))
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::VSOS, page: 2)
        .and_return(instance_double(Faraday::Response, body: empty_response))

      # Mock Representative API responses
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::REPRESENTATIVES, page: 1)
        .and_return(instance_double(Faraday::Response, body: rep_response))
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::REPRESENTATIVES, page: 2)
        .and_return(instance_double(Faraday::Response, body: empty_response))

      # Mock record creation
      allow(AccreditedOrganization).to receive_messages(find_or_create_by: vso_record, find_by: vso_record)
      allow(AccreditedIndividual).to receive(:find_or_create_by).and_return(rep_record)
      allow(Accreditation).to receive(:find_or_create_by).and_return(accreditation_record)

      # Mock record updates
      allow(vso_record).to receive(:update)
      allow(rep_record).to receive(:update)

      # Mock address validation
      allow(RepresentationManagement::AccreditedIndividualsUpdate).to receive(:perform_in)
    end

    it 'processes VSOs and representatives when both counts are valid' do
      job.send(:process_orgs_and_reps)

      # Verify VSO was processed
      expect(AccreditedOrganization).to have_received(:find_or_create_by)
        .with(ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373a', poa_code: 'JQ8')
      expect(vso_record).to have_received(:update)

      # Verify Representative was processed
      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with(ogc_id: 'dfc36f35-0464-450f-a85b-3fa639705826', individual_type: 'representative')
      expect(rep_record).to have_received(:update)

      # Verify Accreditation was created
      expect(Accreditation).to have_received(:find_or_create_by)
        .with(accredited_individual_id: 200, accredited_organization_id: 100)
    end

    context 'when representative count is invalid' do
      before do
        allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::REPRESENTATIVES).and_return(false)
      end

      it 'logs an error and skips processing' do
        expect(Rails.logger).to receive(:error).with(/Representatives count decreased/)
        expect(Rails.logger).to receive(:error).with(/Both Orgs and Reps must have valid counts/)

        job.send(:process_orgs_and_reps)

        expect(AccreditedOrganization).not_to have_received(:find_or_create_by)
        expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
      end
    end

    context 'when VSO count is invalid' do
      before do
        allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::VSOS).and_return(false)
      end

      it 'logs an error and skips processing' do
        expect(Rails.logger).to receive(:error).with(/Veteran service organizations count decreased/)
        expect(Rails.logger).to receive(:error).with(/Both Orgs and Reps must have valid counts/)

        job.send(:process_orgs_and_reps)

        expect(AccreditedOrganization).not_to have_received(:find_or_create_by)
        expect(AccreditedIndividual).not_to have_received(:find_or_create_by)
      end
    end

    context 'when forcing updates' do
      before do
        job.instance_variable_set(:@force_update_types, [RepresentationManagement::REPRESENTATIVES])
        allow(entity_counts).to receive(:valid_count?).with(RepresentationManagement::REPRESENTATIVES).and_return(false)
      end

      it 'processes despite invalid counts' do
        job.send(:process_orgs_and_reps)

        expect(AccreditedOrganization).to have_received(:find_or_create_by)
        expect(AccreditedIndividual).to have_received(:find_or_create_by)
      end
    end
  end

  describe '#update_vsos' do
    let(:vso_response1) { { 'items' => [vso1, vso2] } }
    let(:vso_response2) { { 'items' => [] } }

    let(:vso1) do
      {
        'vsoid' => '9c6f8595-4e84-42e5-b90a-270c422c373a',
        'number' => 210,
        'acceptsElectronicPoas' => false,
        'poa' => 'JQ8',
        'organization' => { 'id' => '09901a71-a3ce-4a85-a5bd-172cce0b6439', 'text' => 'Less Law Firm' }
      }
    end

    let(:vso2) do
      {
        'vsoid' => '8f8d4051-ddcc-4730-973e-9688559a91fc',
        'number' => 194,
        'acceptsElectronicPoas' => true,
        'poa' => 'JOW',
        'organization' => { 'id' => '46f8ef08-4cbc-487b-83df-5ff69ea8893d', 'text' => 'ABC Test' }
      }
    end

    let(:vso_record1) { instance_double(AccreditedOrganization, id: 100) }
    let(:vso_record2) { instance_double(AccreditedOrganization, id: 101) }

    before do
      job.instance_variable_set(:@vso_ids, [])

      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::VSOS, page: 1)
        .and_return(instance_double(Faraday::Response, body: vso_response1))
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::VSOS, page: 2)
        .and_return(instance_double(Faraday::Response, body: vso_response2))

      allow(AccreditedOrganization).to receive(:find_or_create_by) do |args|
        case args[:ogc_id]
        when '9c6f8595-4e84-42e5-b90a-270c422c373a' then vso_record1
        when '8f8d4051-ddcc-4730-973e-9688559a91fc' then vso_record2
        end
      end

      allow(vso_record1).to receive(:update)
      allow(vso_record2).to receive(:update)
    end

    it 'fetches and processes all VSOs' do
      job.send(:update_vsos)

      expect(AccreditedOrganization).to have_received(:find_or_create_by)
        .with(ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373a', poa_code: 'JQ8')
      expect(AccreditedOrganization).to have_received(:find_or_create_by)
        .with(ogc_id: '8f8d4051-ddcc-4730-973e-9688559a91fc', poa_code: 'JOW')

      expect(vso_record1).to have_received(:update).with(
        ogc_id: '9c6f8595-4e84-42e5-b90a-270c422c373a',
        poa_code: 'JQ8',
        name: 'Less Law Firm'
      )
      expect(vso_record2).to have_received(:update).with(
        ogc_id: '8f8d4051-ddcc-4730-973e-9688559a91fc',
        poa_code: 'JOW',
        name: 'ABC Test'
      )

      expect(job.instance_variable_get(:@vso_ids)).to eq([100, 101])
    end

    context 'when an error occurs' do
      before do
        allow(client).to receive(:get_accredited_entities).and_raise(StandardError.new('API error'))
      end

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(/Error updating VSOs: API error/)
        job.send(:update_vsos)
      end
    end
  end

  describe '#update_reps' do
    let(:rep_response1) { { 'items' => [rep1, rep2] } }
    let(:rep_response2) { { 'items' => [] } }

    let(:rep1) do
      {
        'id' => 'ea154c64-bf20-47e0-9866-86ae988776a8',
        'representative' => {
          'lastName' => 'aalaam',
          'middleName' => '',
          'firstName' => 'judy',
          'workNumber' => '555-1234',
          'workEmailAddress' => 'judy@example.com',
          'id' => 'dfc36f35-0464-450f-a85b-3fa639705826'
        },
        'veteransServiceOrganization' => {
          'name' => 'Less Law Firm',
          'poa' => 'JQ8',
          'number' => 210,
          'id' => '9c6f8595-4e84-42e5-b90a-270c422c373a'
        },
        'lastName' => 'aalaam',
        'firstName' => 'judy',
        'middleName' => '',
        'workAddress1' => '123 Work St',
        'workAddress2' => '',
        'workAddress3' => '',
        'workCity' => 'Work City',
        'workState' => 'CA',
        'workZip' => '12345'
      }
    end

    let(:rep2) do
      {
        'id' => 'b50ee54b-ff87-4c78-b41d-7ffe1a8f89e5',
        'representative' => {
          'lastName' => 'abad',
          'middleName' => 'M',
          'firstName' => 'julia',
          'workNumber' => '555-5678',
          'workEmailAddress' => 'julia@example.com',
          'id' => '35d586dc-58cd-4569-a030-557197725165'
        },
        'veteransServiceOrganization' => {
          'name' => 'Less Law Firm',
          'poa' => 'JQ8',
          'number' => 210,
          'id' => '9c6f8595-4e84-42e5-b90a-270c422c373a'
        },
        'lastName' => 'abad',
        'firstName' => 'julia',
        'middleName' => 'M',
        'workAddress1' => '456 Office Blvd',
        'workAddress2' => 'Suite 100',
        'workAddress3' => '',
        'workCity' => 'Office Town',
        'workState' => 'NY',
        'workZip' => '54321'
      }
    end

    let(:rep_record1) { instance_double(AccreditedIndividual, id: 200, raw_address: nil) }
    let(:rep_record2) { instance_double(AccreditedIndividual, id: 201, raw_address: nil) }

    before do
      job.instance_variable_set(:@representative_ids, [])
      job.instance_variable_set(:@representative_json_for_address_validation, [])
      job.instance_variable_set(:@rep_to_vso_associations, {})

      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::REPRESENTATIVES, page: 1)
        .and_return(instance_double(Faraday::Response, body: rep_response1))
      allow(client).to receive(:get_accredited_entities)
        .with(type: RepresentationManagement::REPRESENTATIVES, page: 2)
        .and_return(instance_double(Faraday::Response, body: rep_response2))

      allow(AccreditedIndividual).to receive(:find_or_create_by) do |args|
        case args[:ogc_id]
        when 'dfc36f35-0464-450f-a85b-3fa639705826' then rep_record1
        when '35d586dc-58cd-4569-a030-557197725165' then rep_record2
        end
      end

      allow(rep_record1).to receive(:update)
      allow(rep_record2).to receive(:update)
    end

    it 'fetches and processes all representatives' do
      job.send(:update_reps)

      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with(ogc_id: 'dfc36f35-0464-450f-a85b-3fa639705826', individual_type: 'representative')
      expect(AccreditedIndividual).to have_received(:find_or_create_by)
        .with(ogc_id: '35d586dc-58cd-4569-a030-557197725165', individual_type: 'representative')

      expect(rep_record1).to have_received(:update)
      expect(rep_record2).to have_received(:update)

      expect(job.instance_variable_get(:@representative_ids)).to eq([200, 201])
    end

    it 'tracks VSO associations' do
      job.send(:update_reps)

      associations = job.instance_variable_get(:@rep_to_vso_associations)
      expect(associations[200]).to eq(['9c6f8595-4e84-42e5-b90a-270c422c373a'])
      expect(associations[201]).to eq(['9c6f8595-4e84-42e5-b90a-270c422c373a'])
    end

    it 'adds address validation data when address has changed' do
      old_address = { 'address_line1' => 'Old Address' }
      allow(rep_record1).to receive(:raw_address).and_return(old_address)

      job.send(:update_reps)

      expect(job.instance_variable_get(:@representative_json_for_address_validation)).not_to be_empty
    end

    context 'when an error occurs' do
      before do
        allow(client).to receive(:get_accredited_entities).and_raise(StandardError.new('API error'))
      end

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(/Error updating representatives: API error/)
        job.send(:update_reps)
      end
    end
  end

  describe '#create_or_update_accreditations' do
    let(:vso_record) { instance_double(AccreditedOrganization, id: 100) }
    let(:accreditation1) { instance_double(Accreditation, id: 300) }
    let(:accreditation2) { instance_double(Accreditation, id: 301) }

    before do
      job.instance_variable_set(:@rep_to_vso_associations,
                                200 => %w[vso-ogc-1 vso-ogc-2],
                                201 => ['vso-ogc-1'])
      job.instance_variable_set(:@accreditation_ids, [])

      allow(AccreditedOrganization).to receive(:find_by).with(ogc_id: 'vso-ogc-1').and_return(vso_record)
      allow(AccreditedOrganization).to receive(:find_by).with(ogc_id: 'vso-ogc-2').and_return(nil)

      allow(Accreditation).to receive(:find_or_create_by).and_return(accreditation1, accreditation2)
    end

    it 'creates accreditations for valid VSO associations' do
      job.send(:create_or_update_accreditations)

      expect(Accreditation).to have_received(:find_or_create_by)
        .with(accredited_individual_id: 200, accredited_organization_id: 100)
      expect(Accreditation).to have_received(:find_or_create_by)
        .with(accredited_individual_id: 201, accredited_organization_id: 100)

      expect(job.instance_variable_get(:@accreditation_ids)).to eq([300, 301])
    end

    it 'logs an error for missing VSOs' do
      expect(Rails.logger).to receive(:error).with(/VSO not found for ogc_id: vso-ogc-2/)
      job.send(:create_or_update_accreditations)
    end

    context 'when an error occurs' do
      before do
        allow(Accreditation).to receive(:find_or_create_by).and_raise(StandardError.new('DB error'))
      end

      it 'logs an error' do
        expect(Rails.logger).to receive(:error).with(%r{Error creating/updating accreditations: DB error})
        job.send(:create_or_update_accreditations)
      end
    end
  end

  describe '#delete_removed_accredited_organizations' do
    let(:old_vso) { instance_double(AccreditedOrganization, id: 999) }
    let(:relation) { double('ActiveRecord::Relation') }

    before do
      job.instance_variable_set(:@vso_ids, [100, 101])

      allow(AccreditedOrganization).to receive(:where).and_return(relation)
      allow(relation).to receive(:not).with(id: [100, 101]).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(old_vso)
      allow(old_vso).to receive(:destroy)
    end

    it 'deletes organizations not in the current VSO ids' do
      job.send(:delete_removed_accredited_organizations)
      expect(old_vso).to have_received(:destroy)
    end

    context 'when an error occurs during deletion' do
      before do
        allow(old_vso).to receive(:destroy).and_raise(StandardError.new('Delete error'))
      end

      it 'logs an error' do
        expect(Rails.logger).to receive(:error)
          .with(/Error deleting old accredited organization with ID 999: Delete error/)
        job.send(:delete_removed_accredited_organizations)
      end
    end
  end

  describe '#delete_removed_accreditations' do
    let(:old_accreditation) { instance_double(Accreditation, id: 999) }
    let(:relation) { double('ActiveRecord::Relation') }

    before do
      job.instance_variable_set(:@accreditation_ids, [300, 301])

      allow(Accreditation).to receive(:where).and_return(relation)
      allow(relation).to receive(:not).with(id: [300, 301]).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(old_accreditation)
      allow(old_accreditation).to receive(:destroy)
    end

    it 'deletes accreditations not in the current accreditation ids' do
      job.send(:delete_removed_accreditations)
      expect(old_accreditation).to have_received(:destroy)
    end

    context 'when an error occurs during deletion' do
      before do
        allow(old_accreditation).to receive(:destroy).and_raise(StandardError.new('Delete error'))
      end

      it 'logs an error' do
        expect(Rails.logger).to receive(:error)
          .with(/Error deleting old accreditation with ID 999: Delete error/)
        job.send(:delete_removed_accreditations)
      end
    end
  end

  describe '#data_transform_for_representative' do
    let(:rep) do
      {
        'id' => 'ea154c64-bf20-47e0-9866-86ae988776a8',
        'representative' => {
          'lastName' => 'aalaam',
          'middleName' => 'M',
          'firstName' => 'judy',
          'workNumber' => '555-1234',
          'workEmailAddress' => 'judy@example.com',
          'id' => 'dfc36f35-0464-450f-a85b-3fa639705826'
        },
        'lastName' => 'aalaam',
        'firstName' => 'judy',
        'middleName' => 'M',
        'workAddress1' => '123 Work St',
        'workAddress2' => 'Apt 2',
        'workAddress3' => '',
        'workCity' => 'Work City',
        'workState' => 'CA',
        'workZip' => '12345'
      }
    end

    it 'transforms representative data using work address' do
      result = job.send(:data_transform_for_representative, rep)

      expect(result[:individual_type]).to eq('representative')
      expect(result[:first_name]).to eq('judy')
      expect(result[:middle_initial]).to eq('M')
      expect(result[:last_name]).to eq('aalaam')
      expect(result[:address_line1]).to eq('123 Work St')
      expect(result[:address_line2]).to eq('Apt 2')
      expect(result[:city]).to eq('Work City')
      expect(result[:state_code]).to eq('CA')
      expect(result[:zip_code]).to eq('12345')
      expect(result[:phone]).to eq('555-1234')
      expect(result[:email]).to eq('judy@example.com')
    end
  end

  describe '#validate_rep_addresses' do
    before do
      rep_data = [
        { id: 1, address: { address_line1: '123 Rep St' } },
        { id: 2, address: { address_line1: '456 Rep Ave' } }
      ]
      job.instance_variable_set(:@representative_json_for_address_validation, rep_data)
    end

    it 'queues address validation jobs for representatives' do
      expect(RepresentationManagement::AccreditedIndividualsUpdate).to receive(:perform_in)
        .with(0.minutes, job.instance_variable_get(:@representative_json_for_address_validation).to_json)

      job.send(:validate_rep_addresses)
    end

    it 'sets the batch description to representative-specific text' do
      expect(batch).to receive(:description=)
        .with('Batching representative address updates from GCLAWS Accreditation API')

      job.send(:validate_rep_addresses)
    end
  end

  describe '#finalize_and_send_report' do
    let(:job) { described_class.new }

    before do
      allow(job).to receive(:log_to_slack_channel)
      job.instance_variable_set(:@report, String.new)
      job.instance_variable_set(:@start_time, 2.minutes.ago)
    end

    it 'calculates duration and appends it to the report' do
      allow(job).to receive(:calculate_duration).and_return('2m 30s')

      job.send(:finalize_and_send_report)

      report = job.instance_variable_get(:@report)
      expect(report).to include("\nJob Duration: 2m 30s\n")
    end

    it 'sends the complete report to Slack' do
      initial_report = String.new('Initial report content')
      job.instance_variable_set(:@report, initial_report)
      allow(job).to receive(:calculate_duration).and_return('1m 15s')

      job.send(:finalize_and_send_report)

      expect(job).to have_received(:log_to_slack_channel).with(initial_report)
    end

    it 'uses Time.current as end_time when called' do
      freeze_time = Time.parse('2023-12-01 12:00:00 UTC')
      start_time = freeze_time - 5.minutes

      job.instance_variable_set(:@start_time, start_time)

      travel_to freeze_time do
        expect(job).to receive(:calculate_duration).with(start_time, freeze_time).and_return('5m 0s')
        job.send(:finalize_and_send_report)
      end
    end

    context 'when @start_time is nil' do
      before do
        job.instance_variable_set(:@start_time, nil)
      end

      it 'handles missing start_time gracefully' do
        allow(job).to receive(:calculate_duration).and_return('Unknown')

        job.send(:finalize_and_send_report)

        report = job.instance_variable_get(:@report)
        expect(report).to include("\nJob Duration: Unknown\n")
      end
    end
  end

  describe '#calculate_duration' do
    let(:job) { described_class.new }

    context 'when calculating duration in seconds only' do
      it 'returns seconds format for duration under 1 minute' do
        start_time = Time.parse('2023-12-01 12:00:00 UTC')
        end_time = start_time + 45.seconds

        result = job.send(:calculate_duration, start_time, end_time)

        expect(result).to eq('45s')
      end
    end

    context 'when calculating duration in minutes and seconds' do
      it 'returns minutes and seconds format for 2 minutes 30 seconds' do
        start_time = Time.parse('2023-12-01 12:00:00 UTC')
        end_time = start_time + 2.minutes + 30.seconds

        result = job.send(:calculate_duration, start_time, end_time)

        expect(result).to eq('2m 30s')
      end
    end

    context 'when calculating duration in hours, minutes and seconds' do
      it 'returns full format for 2 hours 15 minutes 30 seconds' do
        start_time = Time.parse('2023-12-01 12:00:00 UTC')
        end_time = start_time + 2.hours + 15.minutes + 30.seconds

        result = job.send(:calculate_duration, start_time, end_time)

        expect(result).to eq('2h 15m 30s')
      end
    end

    context 'when handling edge cases' do
      it 'handles fractional seconds by truncating to integer' do
        start_time = Time.parse('2023-12-01 12:00:00.750 UTC')
        end_time = Time.parse('2023-12-01 12:00:45.250 UTC')

        result = job.send(:calculate_duration, start_time, end_time)

        expect(result).to eq('44s') # 44.5 seconds truncated to 44
      end

      it 'handles same start and end times' do
        time = Time.parse('2023-12-01 12:00:00 UTC')

        result = job.send(:calculate_duration, time, time)

        expect(result).to eq('0s')
      end

      it 'works with Time objects that have different time zones' do
        start_time = Time.parse('2023-12-01 12:00:00 UTC')
        end_time = Time.parse('2023-12-01 13:15:30 EST') # 1h 15m 30s later in UTC

        result = job.send(:calculate_duration, start_time, end_time)

        expect(result).to eq('6h 15m 30s') # EST is UTC-5, so 13:15:30 EST = 18:15:30 UTC
      end
    end
  end
end
