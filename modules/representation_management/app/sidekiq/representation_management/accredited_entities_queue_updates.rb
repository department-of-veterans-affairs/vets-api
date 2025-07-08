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

    AGENTS = 'agents'
    ATTORNEYS = 'attorneys'
    # Define a configuration map for entity types
    ENTITY_CONFIG = {
      AGENTS => {
        api_type: 'agent',
        individual_type: 'claims_agent',
        responses_var: :@agent_responses,
        ids_var: :@agent_ids,
        json_var: :@agent_json_for_address_validation,
        validation_description: 'Batching agent address updates from GCLAWS Accreditation API'
      },
      ATTORNEYS => {
        api_type: 'attorney',
        individual_type: 'attorney',
        responses_var: :@attorney_responses,
        ids_var: :@attorney_ids,
        json_var: :@attorney_json_for_address_validation,
        validation_description: 'Batching attorney address updates from GCLAWS Accreditation API'
      }
    }.freeze

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
      @org_responses = []
      @agent_ids = []
      @attorney_ids = []
      # @org_ids = []
      @agent_json_for_address_validation = []
      @attorney_json_for_address_validation = []
      @entity_counts = RepresentationManagement::AccreditationApiEntityCount.new

      # Don't save fresh API counts if updates are forced
      @entity_counts.save_api_counts unless @force_update_types.any?
      # TODO: Refactor to do all the valid entity counting in one place and create instance variables
      # Maybe one hash with types as keys and true/false as values
      process_entity_type(AGENTS)
      process_entity_type(ATTORNEYS)
      process_orgs_and_reps
      delete_removed_accredited_individuals
    rescue => e
      log_error("Error in AccreditedEntitiesQueueUpdates: #{e.message}")
    end

    private

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

    def process_orgs_and_reps
      # Check if there are any force update types specified AND
      # none of them are representatives or veteran_service_organizations
      return if @force_update_types.any? &&
                !@force_update_types.intersect?(orgs_and_reps)

      orgs_and_reps.each do |type|
        unless @entity_counts.valid_count?(type) || @force_update_types.include?(type)
          log_error("#{type.humanize} count decreased by more than #{DECREASE_THRESHOLD * 100}% - skipping update")
        end
      end

      unless orgs_and_reps_both_valid? || @force_update_types.intersect?(orgs_and_reps)
        log_error('Both Orgs and Reps must have valid counts to process together - skipping update for both')
        return
      end

      # Process orgs
      update_orgs
      validate_org_addresses

      # Process reps
      update_reps
      validate_rep_addresses
    end

    # Fetches agent data from the GCLAWS API and updates database records
    #
    # @return [void]
    def update_agents
      update_entities(AGENTS)
    end

    # Fetches attorney data from the GCLAWS API and updates database records
    #
    # @return [void]
    def update_attorneys
      update_entities(ATTORNEYS)
    end

    # Generic method to update entities of a specific type
    #
    # @param entity_type [String] The type of entity to update ('agents' or 'attorneys')
    # @return [void]
    def update_entities(entity_type)
      config = ENTITY_CONFIG[entity_type]
      page = 1

      loop do
        response = client.get_accredited_entities(type: entity_type, page:)
        entities = response.body['items']
        break if entities.empty?

        instance_variable_get(config[:responses_var]) << entities
        entities.each { |entity| handle_entity_record(entity, config) }
        page += 1
      end
    end

    def update_orgs
      # This will require custom implementation, it can't use handle_entity_record as is.
      # Rename update_entities to update_individuals then add custom implementation for orgs here.
    end

    # Removes AccreditedIndividual records that are no longer present in the GCLAWS API
    #
    # @return [void]
    def delete_removed_accredited_individuals
      AccreditedIndividual.where.not(id: @agent_ids + @attorney_ids).find_each do |record|
        record.destroy
      rescue => e
        log_error("Error deleting old accredited individual with ID #{record.id}: #{e.message}")
      end
    end

    # Handle an individual entity
    #
    # @param entity [Hash] The entity data from the API
    # @param config [Hash] Configuration for the entity type
    # @return [void]
    def handle_entity_record(entity, config)
      api_type = config[:api_type]
      entity_hash = send("data_transform_for_#{api_type}", entity)

      # Find or create record
      entity_identifier = { individual_type: config[:individual_type], ogc_id: entity['id'] }
      record = AccreditedIndividual.find_or_create_by(entity_identifier)

      # Check if address validation is needed
      raw_address = send("raw_address_for_#{api_type}", entity)
      if record.raw_address != raw_address
        json_method = "individual_#{api_type}_json"
        instance_variable_get(config[:json_var]) << send(json_method, record, entity)
      end

      # Update record and store ID
      record.update(entity_hash)
      instance_variable_get(config[:ids_var]) << record.id
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
      validate_entity_addresses(AGENTS)
    end

    # Queues address validation jobs for attorneys
    #
    # @return [void]
    def validate_attorney_addresses
      validate_entity_addresses(ATTORNEYS)
    end

    # Queues address validation jobs for a specific entity type
    #
    # @param entity_type [String] The entity type to validate ('agents' or 'attorneys')
    # @return [void]
    def validate_entity_addresses(entity_type)
      config = ENTITY_CONFIG[entity_type]
      json_var = config[:json_var]
      description = config[:validation_description]

      validate_addresses(
        instance_variable_get(json_var),
        description
      )
    end

    # @return [RepresentationManagement::GCLAWS::Client] The client for GCLAWS API calls
    def client
      RepresentationManagement::GCLAWS::Client
    end

    def orgs_and_reps
      %w[representatives veteran_service_organizations]
    end

    def orgs_and_reps_both_valid?
      orgs_and_reps.all? { |type| @entity_counts.valid_count?(type) }
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
