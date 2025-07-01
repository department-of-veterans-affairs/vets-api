# frozen_string_literal: true

require 'sidekiq'

module RepresentationManagement
  # This is the first job in a two job process for updating accredited entities.
  # Processes and updates accredited entities (agents and attorneys) from the GCLAWS API
  #
  # This Sidekiq job fetches data about accredited agents and attorneys from the GCLAWS API,
  # creates or updates records in the database, validates addresses through the VAProfile
  # address validation service, and removes records that are no longer present in the API.
  # That address validation is done in the second job, RepresentationManagement::AccreditedIndividualsUpdate.
  #
  # The job includes data validation to prevent large decreases in entity counts, which might
  # indicate data quality issues. This validation can be bypassed for specific entity types
  # using the force_update_types parameter.
  #
  # @example Enqueue the job to process all entity types
  #   RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async
  #
  # @example Force update for a specific entity type
  #   RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(['agents'])
  #
  # @example Force update for multiple entity types
  #   RepresentationManagement::AccreditedEntitiesQueueUpdates.perform_async(['agents', 'attorneys'])
  class AccreditedEntitiesQueueUpdates
    include Sidekiq::Job

    # Maximum allowed decrease percentage for entity counts before updates are blocked
    DECREASE_THRESHOLD = RepresentationManagement::AccreditationApiEntityCount::DECREASE_THRESHOLD

    # Number of records to process in each address validation batch
    SLICE_SIZE = 30

    # Main job method that processes accredited entities
    #
    # @param force_update_types [Array<String>] Optional array of entity types to force update
    #   regardless of count validation ('agents', 'attorneys')
    # @return [void]
    def perform(force_update_types = [])
      # The force_update_types are the accredited entity types that should be updated regardless of the current counts.
      @force_update_types = force_update_types
      @agent_responses = []
      @attorney_responses = []
      @agent_ids = []
      @attorney_ids = []
      @agent_json_for_address_validation = []
      @attorney_json_for_address_validation = []
      @entity_counts = RepresentationManagement::AccreditationApiEntityCount.new

      # Don't save fresh API counts if updates are forced
      @entity_counts.save_api_counts unless @force_update_types.any?
      process_entity_type('agents')
      process_entity_type('attorneys')
      delete_old_accredited_individuals
    rescue => e
      log_error("Error in AccreditedEntitiesQueueUpdates: #{e.message}")
    end

    private

    # @return [RepresentationManagement::GCLAWS::Client] The client for GCLAWS API calls
    def client
      RepresentationManagement::GCLAWS::Client
    end

    # Transforms agent data from the GCLAWS API into a format suitable for the AccreditedIndividual model
    #
    # @param agent [Hash] Raw agent data from the GCLAWS API
    # @return [Hash] Transformed data for AccreditedIndividual record
    def data_transform_for_agent(agent)
      data_transform_for_entity(agent, 'claims_agent', {
                                  country_code_iso3: agent['workCountry'],
                                  country_name: agent['workCountry'],
                                  phone: agent['workPhoneNumber'],
                                  email: agent['workEmailAddress'],
                                  raw_address: raw_address_for_agent(agent)
                                })
    end

    # Transforms attorney data from the GCLAWS API into a format suitable for the AccreditedIndividual model
    #
    # @param attorney [Hash] Raw attorney data from the GCLAWS API
    # @return [Hash] Transformed data for AccreditedIndividual record
    def data_transform_for_attorney(attorney)
      data_transform_for_entity(attorney, 'attorney', {
                                  city: attorney['workCity'],
                                  state_code: attorney['workState'],
                                  phone: attorney['workNumber'],
                                  email: attorney['emailAddress']
                                })
    end

    # Base transformation method for both agents and attorneys
    #
    # @param entity [Hash] Raw entity data from the GCLAWS API
    # @param entity_type [String] The type of entity ('claims_agent' or 'attorney')
    # @param extra_attrs [Hash] Additional attributes specific to this entity type
    # @return [Hash] Transformed data for AccreditedIndividual record
    def data_transform_for_entity(entity, entity_type, extra_attrs = {})
      {
        individual_type: entity_type,
        registration_number: entity['number'],
        poa_code: entity['poa'],
        ogc_id: entity['id'],
        first_name: entity['firstName'],
        middle_initial: entity['middleName'].to_s.strip.first,
        last_name: entity['lastName'],
        address_line1: entity['workAddress1'],
        address_line2: entity['workAddress2'],
        address_line3: entity['workAddress3'],
        zip_code: entity['workZip']
      }.merge(extra_attrs)
    end

    # Removes AccreditedIndividual records that are no longer present in the GCLAWS API
    #
    # @return [void]
    def delete_old_accredited_individuals
      AccreditedIndividual.where.not(id: @agent_ids + @attorney_ids).find_each do |record|
        record.destroy
      rescue => e
        log_error("Error deleting old accredited individual with ID #{record.id}: #{e.message}")
      end
    end

    # Creates a JSON object for an agent's address, used for address validation
    #
    # @param record [AccreditedIndividual] The database record for the agent
    # @param agent [Hash] Raw agent data from the GCLAWS API
    # @return [Hash] JSON structure for address validation
    def individual_agent_json(record, agent)
      individual_entity_json(record, agent, :agent, { city: nil })
    end

    # Creates a JSON object for an attorney's address, used for address validation
    #
    # @param record [AccreditedIndividual] The database record for the attorney
    # @param attorney [Hash] Raw attorney data from the GCLAWS API
    # @return [Hash] JSON structure for address validation
    def individual_attorney_json(record, attorney)
      attorney_raw_address = raw_address_for_attorney(attorney)
      individual_entity_json(
        record,
        attorney,
        :attorney,
        {
          city: attorney_raw_address['city'],
          state: { state_code: attorney_raw_address['state_code'] }
        }
      )
    end

    # Base method to create a JSON object for entity address validation
    #
    # @param record [AccreditedIndividual] The database record for the entity
    # @param entity [Hash] Raw entity data from the GCLAWS API
    # @param entity_type [Symbol] The type of entity (:agent or :attorney)
    # @param additional_fields [Hash] Additional address fields specific to this entity type
    # @return [Hash] JSON structure for address validation
    def individual_entity_json(record, entity, entity_type, additional_fields = {})
      raw_address = send("raw_address_for_#{entity_type}", entity)

      {
        id: record.id,
        address: {
          address_pou: 'RESIDENCE/CHOICE',
          address_line1: raw_address['address_line1'],
          address_line2: raw_address['address_line2'],
          address_line3: raw_address['address_line3'],
          zip_code5: raw_address['zip_code']
        }.merge(additional_fields)
      }
    end

    # Processes entities of a specific type based on count validation and force update settings
    #
    # @param entity_type [String] The type of entity to process ('agents' or 'attorneys')
    # @return [void]
    def process_entity_type(entity_type)
      # Don't process if we are forcing updates for other types
      return if @force_update_types.any? && @force_update_types.exclude?(entity_type)

      if @entity_counts.valid_count?(entity_type) || @force_update_types.include?(entity_type)
        if entity_type == 'agents'
          update_agents
          validate_agent_addresses
        else # attorneys
          update_attorneys
          validate_attorney_addresses
        end
      else
        entity_display = entity_type.capitalize
        log_error("#{entity_display} count decreased by more than #{DECREASE_THRESHOLD * 100}% - skipping update")
      end
    end

    # Extracts address data from an entity record with optional extra fields
    #
    # @param entity [Hash] Raw entity data from the GCLAWS API
    # @param extra_fields [Hash] Additional fields to include, with mapping to entity keys
    # @return [Hash] Standardized address data
    def raw_address_from_entity(entity, extra_fields = {})
      {
        address_line1: entity['workAddress1'],
        address_line2: entity['workAddress2'],
        address_line3: entity['workAddress3'],
        zip_code: entity['workZip']
      }.merge(extra_fields.transform_values { |key| entity[key] })
        .transform_keys(&:to_s)
    end

    # Creates a standardized address hash for an agent
    #
    # @param agent [Hash] Raw agent data from the GCLAWS API
    # @return [Hash] Standardized address data
    def raw_address_for_agent(agent)
      raw_address_from_entity(agent, work_country: 'workCountry')
    end

    # Creates a standardized address hash for an attorney
    #
    # @param attorney [Hash] Raw attorney data from the GCLAWS API
    # @return [Hash] Standardized address data
    def raw_address_for_attorney(attorney)
      raw_address_from_entity(attorney, city: 'workCity', state_code: 'workState')
    end

    # Fetches agent data from the GCLAWS API and updates database records
    #
    # @return [void]
    def update_agents
      page = 1
      loop do
        response = client.get_accredited_entities(type: 'agents', page:)
        agents = response.body['items']
        break if agents.empty?

        @agent_responses << agents
        agents.each do |agent|
          agent_hash = data_transform_for_agent(agent)
          # The agent_identifier is the minimum set of attributes needed to identify an agent.
          agent_identifier = { individual_type: 'claims_agent', ogc_id: agent['id'] }
          record = AccreditedIndividual.find_or_create_by(agent_identifier)
          # Only enqueue address validation if the address has changed
          if record.raw_address != raw_address_for_agent(agent)
            @agent_json_for_address_validation << individual_agent_json(record, agent)
          end
          record.update(agent_hash)
          @agent_ids << record.id
        end
        page += 1
      end
    end

    # Fetches attorney data from the GCLAWS API and updates database records
    #
    # @return [void]
    def update_attorneys
      page = 1
      loop do
        response = client.get_accredited_entities(type: 'attorneys', page:)
        attorneys = response.body['items']
        break if attorneys.empty?

        @attorney_responses << attorneys
        attorneys.each do |attorney|
          attorney_hash = data_transform_for_attorney(attorney)
          # The attorney_identifier is the minimum set of attributes needed to identify an attorney.
          attorney_identifier = { individual_type: 'attorney', ogc_id: attorney['id'] }
          record = AccreditedIndividual.find_or_create_by(attorney_identifier)
          # Only enqueue address validation if the address has changed
          if record.raw_address != raw_address_for_attorney(attorney)
            @attorney_json_for_address_validation << individual_attorney_json(record, attorney)
          end
          record.update(attorney_hash)
          @attorney_ids << record.id
        end
        page += 1
      end
    end

    # Queues address validation jobs for a batch of records
    #
    # @param records_for_validation [Array<Hash>] Records to validate
    # @param description [String] Description for the Sidekiq batch
    # @return [void]
    def validate_addresses(records_for_validation,
                           description = 'Batching address updates from GCLAWS Accreditation API')
      return if records_for_validation.empty?

      delay = 0
      batch = Sidekiq::Batch.new
      batch.description = description

      begin
        batch.jobs do
          records_for_validation.each_slice(SLICE_SIZE) do |individuals|
            json_individuals = individuals.to_json
            RepresentationManagement::AccreditedIndividualsUpdate.perform_in(delay.minutes, json_individuals)
            delay += 1
          end
        end
      rescue => e
        log_error("Error queuing address updates: #{e.message}")
      end
    end

    # Queues address validation jobs for agents
    #
    # @return [void]
    def validate_agent_addresses
      validate_addresses(
        @agent_json_for_address_validation, 'Batching agent address updates from GCLAWS Accreditation API'
      )
    end

    # Queues address validation jobs for attorneys
    #
    # @return [void]
    def validate_attorney_addresses
      validate_addresses(
        @attorney_json_for_address_validation, 'Batching attorney address updates from GCLAWS Accreditation API'
      )
    end

    # Logs an error message to the Rails logger
    #
    # @param message [String] The error message to log
    # @return [void]
    def log_error(message)
      Rails.logger.error("RepresentationManagement::AccreditedEntitiesQueueUpdates error: #{message}")
    end
  end
end
