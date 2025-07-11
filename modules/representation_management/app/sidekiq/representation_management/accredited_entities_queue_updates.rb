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

    AGENTS = RepresentationManagement::AGENTS
    ATTORNEYS = RepresentationManagement::ATTORNEYS
    REPRESENTATIVES = RepresentationManagement::REPRESENTATIVES
    VSOS = RepresentationManagement::VSOS
    ENTITY_CONFIG = RepresentationManagement::ENTITY_CONFIG

    # Main job method that processes accredited entities
    #
    # @param force_update_types [Array<String>] Optional array of entity types to force update
    #   regardless of count validation ('agents', 'attorneys', 'representatives', 'veteran_service_organizations')
    # @return [void]
    def perform(force_update_types = [])
      @force_update_types = force_update_types
      initialize_instance_variables
      @entity_counts = RepresentationManagement::AccreditationApiEntityCount.new

      # Don't save fresh API counts if updates are forced
      @entity_counts.save_api_counts unless @force_update_types.any?
      process_entity_type(AGENTS)
      process_entity_type(ATTORNEYS)
      process_orgs_and_reps
      delete_removed_accredited_individuals
      delete_removed_accredited_organizations
      delete_removed_accreditations
    rescue => e
      log_error("Error in AccreditedEntitiesQueueUpdates: #{e.message}")
    end

    private

    def initialize_instance_variables
      @agent_ids = []
      @attorney_ids = []
      @vso_ids = []
      @representative_ids = []
      @agent_json_for_address_validation = []
      @attorney_json_for_address_validation = []
      @representative_json_for_address_validation = []
      @rep_to_vso_associations = {}
      @accreditation_ids = []
    end

    # Processes entities of a specific type based on count validation and force update settings
    #
    # @param entity_type [String] The type of entity to process ('agents' or 'attorneys')
    # @return [void]
    def process_entity_type(entity_type)
      # Don't process if we are forcing updates for other types
      return if @force_update_types.any? && @force_update_types.exclude?(entity_type)

      if @entity_counts.valid_count?(entity_type) || @force_update_types.include?(entity_type)
        if entity_type == AGENTS
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

      # Process VSOs first (must exist before representatives can reference them)
      update_vsos

      # Process representatives
      update_reps
      validate_rep_addresses

      # Create or update join records
      create_or_update_accreditations
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

        entities.each { |entity| handle_entity_record(entity, config) }
        page += 1
      end
    end

    # Fetches VSO data from the GCLAWS API and updates database records
    #
    # @return [void]
    def update_vsos
      page = 1

      loop do
        response = client.get_accredited_entities(type: VSOS, page:)
        vsos = response.body['items']
        break if vsos.empty?

        vsos.each { |vso| handle_vso_record(vso) }
        page += 1
      end
    rescue => e
      log_error("Error updating VSOs: #{e.message}")
    end

    # Process individual VSO record
    #
    # @param vso [Hash] VSO data from the API
    # @return [void]
    def handle_vso_record(vso)
      vso_hash = data_transform_for_vso(vso)

      # Find or create record by ogc_id and poa_code
      record = AccreditedOrganization.find_or_create_by(ogc_id: vso['vsoid'], poa_code: vso['poa'])

      # Update record
      record.update(vso_hash)
      @vso_ids << record.id
    rescue => e
      log_error("Error handling VSO record with ID #{vso['vsoid']}: #{e.message}")
    end

    # Transforms VSO data from the GCLAWS API into a format suitable for the AccreditedOrganization model
    #
    # @param vso [Hash] Raw VSO data from the GCLAWS API
    # @return [Hash] Transformed data for AccreditedOrganization record
    def data_transform_for_vso(vso)
      {
        ogc_id: vso['vsoid'],
        poa_code: vso['poa'],
        name: vso['organization']['text']
      }
    end

    # Fetches representative data from the GCLAWS API and updates database records
    #
    # @return [void]
    def update_reps
      page = 1

      loop do
        response = client.get_accredited_entities(type: REPRESENTATIVES, page:)
        representatives = response.body['items']
        break if representatives.empty?

        representatives.each { |rep| handle_representative_record(rep) }
        page += 1
      end
    rescue => e
      log_error("Error updating representatives: #{e.message}")
    end

    # Process individual representative record
    #
    # @param rep [Hash] Representative data from the API
    # @return [void]
    def handle_representative_record(rep)
      rep_hash = data_transform_for_representative(rep)

      # Find or create record by ogc_id and individual_type
      rep_ogc_id = rep['representative']['id']
      record = AccreditedIndividual.find_or_create_by(
        ogc_id: rep_ogc_id,
        individual_type: 'representative'
      )

      # Check if address validation is needed
      raw_address = raw_address_for_representative(rep)
      if record.raw_address != raw_address
        @representative_json_for_address_validation << individual_representative_json(record, rep)
      end

      # Update record
      record.update(rep_hash)
      @representative_ids << record.id

      # Track VSO associations for this representative
      vso_ogc_id = rep['veteransServiceOrganization']['id']
      @rep_to_vso_associations[record.id] ||= []
      @rep_to_vso_associations[record.id] << vso_ogc_id unless @rep_to_vso_associations[record.id].include?(vso_ogc_id)
    rescue => e
      log_error("Error handling representative record with ID #{rep['representative']['id']}: #{e.message}")
    end

    # Transforms representative data from the GCLAWS API into a format suitable for the AccreditedIndividual model
    #
    # @param rep [Hash] Raw representative data from the GCLAWS API
    # @return [Hash] Transformed data for AccreditedIndividual record
    def data_transform_for_representative(rep)
      data_transform_for_entity(rep['representative'], 'representative', {
                                  city: rep['workCity'],
                                  state_code: rep['workState'],
                                  phone: rep['representative']['workNumber'],
                                  email: rep['representative']['workEmailAddress'],
                                  address_line1: rep['workAddress1'],
                                  address_line2: rep['workAddress2'],
                                  address_line3: rep['workAddress3'],
                                  zip_code: rep['workZip'],
                                  raw_address: raw_address_for_representative(rep)
                                })
    end

    # Creates a standardized address hash for a representative
    #
    # @param rep [Hash] Raw representative data from the GCLAWS API
    # @return [Hash] Standardized address data
    def raw_address_for_representative(rep)
      {
        'address_line1' => rep['workAddress1'],
        'address_line2' => rep['workAddress2'],
        'address_line3' => rep['workAddress3'],
        'city' => rep['workCity'],
        'state_code' => rep['workState'],
        'zip_code' => rep['workZip']
      }
    end

    # Creates a JSON object for a representative's address, used for address validation
    #
    # @param record [AccreditedIndividual] The database record for the representative
    # @param rep [Hash] Raw representative data from the GCLAWS API
    # @return [Hash] JSON structure for address validation
    def individual_representative_json(record, rep)
      rep_raw_address = raw_address_for_representative(rep)
      individual_entity_json(
        record,
        rep,
        :representative,
        {
          city: rep_raw_address['city'],
          state: { state_code: rep_raw_address['state_code'] }
        }
      )
    end

    # Removes AccreditedIndividual records that are no longer present in the GCLAWS API
    #
    # @return [void]
    def delete_removed_accredited_individuals
      AccreditedIndividual.where.not(id: @agent_ids + @attorney_ids + @representative_ids).find_each do |record|
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
      data_transform_for_entity(agent, ENTITY_CONFIG.send(AGENTS).individual_type, {
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
      data_transform_for_entity(attorney, ENTITY_CONFIG.send(ATTORNEYS).individual_type, {
                                  city: attorney['workCity'],
                                  state_code: attorney['workState'],
                                  phone: attorney['workNumber'],
                                  email: attorney['emailAddress'],
                                  raw_address: raw_address_for_attorney(attorney)
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
    # @param entity_type [Symbol] The type of entity (:agent, :attorney, or :representative)
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

    # Queues address validation jobs for representatives
    #
    # @return [void]
    def validate_rep_addresses
      validate_entity_addresses(REPRESENTATIVES)
    end

    # Queues address validation jobs for a specific entity type
    #
    # @param entity_type [String] The entity type to validate ('agents', 'attorneys', or 'representatives')
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

    # Logs an error message to the Rails logger
    #
    # @param message [String] The error message to log
    # @return [void]
    def log_error(message)
      Rails.logger.error("RepresentationManagement::AccreditedEntitiesQueueUpdates error: #{message}")
    end

    # Helper method to get array of org and rep types
    #
    # @return [Array<String>]
    def orgs_and_reps
      [REPRESENTATIVES, VSOS]
    end

    # Check if both orgs and reps have valid counts
    #
    # @return [Boolean]
    def orgs_and_reps_both_valid?
      @entity_counts.valid_count?(REPRESENTATIVES) && @entity_counts.valid_count?(VSOS)
    end

    # Removes AccreditedOrganization records that are no longer present in the GCLAWS API
    #
    # @return [void]
    def delete_removed_accredited_organizations
      AccreditedOrganization.where.not(id: @vso_ids).find_each do |record|
        record.destroy
      rescue => e
        log_error("Error deleting old accredited organization with ID #{record.id}: #{e.message}")
      end
    end

    # Removes Accreditation records that are no longer valid
    #
    # @return [void]
    def delete_removed_accreditations
      Accreditation.where.not(id: @accreditation_ids).find_each do |record|
        record.destroy
      rescue => e
        log_error("Error deleting old accreditation with ID #{record.id}: #{e.message}")
      end
    end

    # Creates or updates Accreditation records based on representative-VSO associations
    #
    # @return [void]
    def create_or_update_accreditations
      @rep_to_vso_associations.each do |rep_id, vso_ogc_ids|
        vso_ogc_ids.each do |vso_ogc_id|
          # Find the VSO by ogc_id
          vso = AccreditedOrganization.find_by(ogc_id: vso_ogc_id)

          # Skip if VSO not found
          if vso.nil?
            log_error("VSO not found for ogc_id: #{vso_ogc_id} when creating accreditation")
            next
          end

          # Find or create the accreditation
          accreditation = Accreditation.find_or_create_by(
            accredited_individual_id: rep_id,
            accredited_organization_id: vso.id
          )

          @accreditation_ids << accreditation.id
        end
      end
    rescue => e
      log_error("Error creating/updating accreditations: #{e.message}")
    end
  end
end
