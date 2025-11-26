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
  # rubocop:disable Metrics/ClassLength
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
      setup_ingestion
      process_all_entities
      cleanup_removed_records
      complete_ingestion_log
    rescue => e
      handle_ingestion_error(e)
    ensure
      finalize_and_send_report
    end

    private

    def initialize_instance_variables
      @start_time = Time.current
      @report = String.new
      @agent_ids = []
      @attorney_ids = []
      @vso_ids = []
      @representative_ids = []
      @agent_ids_for_address_validation = []
      @attorney_ids_for_address_validation = []
      @representative_ids_for_address_validation = []
      @rep_to_vso_associations = {}
      @accreditation_ids = []
      @processing_error_types = []
      @expected_counts = {}
      @count_mismatch_types = []
    end

    def setup_daily_report
      @report << 'RepresentationManagement::AccreditedEntitiesQueueUpdates Report'
      @report << "📊 **Entity Counts:**\n"
      @report << "```\n#{@entity_counts&.count_report || 'Entity counts unavailable'}\n```\n"
    end

    def finalize_and_send_report
      end_time = Time.current
      duration = calculate_duration(@start_time, end_time)

      # Add deletion skip summary
      add_deletion_skip_summary

      @report << "\nJob Duration: #{duration}\n"
      log_to_slack_channel(@report)
    end

    # Sets up the ingestion process by initializing variables and starting the log
    #
    # @return [void]
    def setup_ingestion
      initialize_instance_variables
      @ingestion_log = RepresentationManagement::AccreditationDataIngestionLog.start_ingestion!(
        dataset: :accreditation_api
      )
      @entity_counts = RepresentationManagement::AccreditationApiEntityCount.new
      setup_daily_report
      # Don't save fresh API counts if updates are forced
      @entity_counts.save_api_counts unless @force_update_types.any?
    end

    # Processes all entity types
    #
    # @return [void]
    def process_all_entities
      process_entity_type(AGENTS)
      process_entity_type(ATTORNEYS)
      process_orgs_and_reps
    end

    # Cleans up removed records from the database
    #
    # @return [void]
    def cleanup_removed_records
      remove_skipped_deletions
      delete_removed_accredited_individuals
      delete_removed_accredited_organizations
      delete_removed_accreditations
    end

    # Handles errors during ingestion
    #
    # @param error [Exception] The error that occurred
    # @return [void]
    def handle_ingestion_error(error)
      log_error("Error in AccreditedEntitiesQueueUpdates: #{error.message}")
      fail_ingestion_log("Error in AccreditedEntitiesQueueUpdates: #{error.message}")
    end

    # Adds a summary of skipped deletions to the report
    #
    # @return [void]
    def add_deletion_skip_summary
      skipped_types = (@processing_error_types + @count_mismatch_types.map(&:to_s)).uniq
      return if skipped_types.empty?

      @report << "\n⚠️ **Deletion Skipped for Some Entity Types:**\n"

      if @processing_error_types.any?
        @report << "Due to errors during processing:\n"
        @processing_error_types.each { |type| @report << "  - #{type.humanize}\n" }
      end

      if @count_mismatch_types.any?
        threshold_display = (DECREASE_THRESHOLD.abs * 100).round(0)
        @report << "Due to count mismatches (>#{threshold_display}% decrease):\n"
        @count_mismatch_types.each do |type|
          expected = @expected_counts[type]
          actual = get_processed_count_for_type(type)
          change = ((actual - expected).to_f / expected * 100).round(2)
          @report << "  - #{type.to_s.humanize}: Expected #{expected}, Processed #{actual} (#{change}% change)\n"
        end
      end
    end

    # Gets the processed count for a given entity type
    #
    # @param type [Symbol] The entity type
    # @return [Integer] The number of processed records
    def get_processed_count_for_type(type)
      case type
      when :agents then @agent_ids.uniq.compact.size
      when :attorneys then @attorney_ids.uniq.compact.size
      when :veteran_service_organizations then @vso_ids.uniq.compact.size
      when :representatives then @representative_ids.uniq.compact.size
      else 0
      end
    end

    # Processes entities of a specific type based on count validation and force update settings
    #
    # @param entity_type [String] The type of entity to process ('agents' or 'attorneys')
    # @return [void]
    def process_entity_type(entity_type)
      return if should_skip_entity_type?(entity_type)

      @ingestion_log&.mark_entity_running!(entity_type)

      if should_process_entity_type?(entity_type)
        process_valid_entity_type(entity_type)
      else
        handle_invalid_entity_count(entity_type)
      end
    rescue => e
      @ingestion_log&.mark_entity_failed!(entity_type, error: e.message)
      raise
    end

    # Determines if an entity type should be skipped
    #
    # @param entity_type [String] The entity type
    # @return [Boolean]
    def should_skip_entity_type?(entity_type)
      @force_update_types.any? && @force_update_types.exclude?(entity_type)
    end

    # Determines if an entity type should be processed
    #
    # @param entity_type [String] The entity type
    # @return [Boolean]
    def should_process_entity_type?(entity_type)
      @entity_counts.valid_count?(entity_type) || @force_update_types.include?(entity_type)
    end

    # Processes a validated entity type
    #
    # @param entity_type [String] The entity type
    # @return [void]
    def process_valid_entity_type(entity_type)
      @expected_counts[entity_type.to_sym] = @entity_counts.current_api_counts[entity_type.to_sym]

      if entity_type == AGENTS
        process_agents
      else
        process_attorneys
      end

      @ingestion_log&.mark_entity_success!(entity_type, count: entity_count_for(entity_type))
    end

    # Processes agents
    #
    # @return [void]
    def process_agents
      update_agents
      @report << "Agents processed: #{@agent_ids.uniq.compact.size}\n"
      validate_agent_addresses
    end

    # Processes attorneys
    #
    # @return [void]
    def process_attorneys
      update_attorneys
      @report << "Attorneys processed: #{@attorney_ids.uniq.compact.size}\n"
      validate_attorney_addresses
    end

    # Returns the count for a specific entity type
    #
    # @param entity_type [String] The entity type
    # @return [Integer]
    def entity_count_for(entity_type)
      entity_type == AGENTS ? @agent_ids.uniq.compact.size : @attorney_ids.uniq.compact.size
    end

    # Handles invalid entity counts
    #
    # @param entity_type [String] The entity type
    # @return [void]
    def handle_invalid_entity_count(entity_type)
      entity_display = entity_type.capitalize
      log_error("#{entity_display} count decreased by more than #{DECREASE_THRESHOLD * 100}% - skipping update")
      @ingestion_log&.mark_entity_failed!(
        entity_type,
        error: 'Count validation failed',
        threshold: DECREASE_THRESHOLD
      )
    end

    def process_orgs_and_reps
      return if should_skip_orgs_and_reps?

      mark_orgs_and_reps_running
      log_invalid_counts_for_orgs_and_reps
      return unless can_process_orgs_and_reps?

      capture_expected_counts_for_orgs_and_reps
      process_vsos_and_reps
      create_or_update_accreditations
    rescue => e
      mark_orgs_and_reps_failed(e.message)
      raise
    end

    # Determines if orgs and reps should be skipped
    #
    # @return [Boolean]
    def should_skip_orgs_and_reps?
      @force_update_types.any? && !@force_update_types.intersect?(orgs_and_reps)
    end

    # Marks organizations and representatives as running
    #
    # @return [void]
    def mark_orgs_and_reps_running
      @ingestion_log&.mark_entity_running!(REPRESENTATIVES)
      @ingestion_log&.mark_entity_running!(VSOS)
    end

    # Logs invalid counts for organizations and representatives
    #
    # @return [void]
    def log_invalid_counts_for_orgs_and_reps
      orgs_and_reps.each do |type|
        unless @entity_counts.valid_count?(type) || @force_update_types.include?(type)
          log_error("#{type.humanize} count decreased by more than #{DECREASE_THRESHOLD * 100}% - skipping update")
        end
      end
    end

    # Determines if organizations and representatives can be processed
    #
    # @return [Boolean]
    def can_process_orgs_and_reps?
      if orgs_and_reps_both_valid? || @force_update_types.intersect?(orgs_and_reps)
        true
      else
        handle_invalid_orgs_and_reps_counts
        false
      end
    end

    # Handles invalid counts for organizations and representatives
    #
    # @return [void]
    def handle_invalid_orgs_and_reps_counts
      log_error('Both Orgs and Reps must have valid counts to process together - skipping update for both')
      mark_orgs_and_reps_failed('Both Orgs and Reps must have valid counts')
    end

    # Captures expected counts for organizations and representatives
    #
    # @return [void]
    def capture_expected_counts_for_orgs_and_reps
      api_counts = @entity_counts.current_api_counts
      @expected_counts[:veteran_service_organizations] = api_counts[:veteran_service_organizations]
      @expected_counts[:representatives] = api_counts[:representatives]
    end

    # Processes VSOs and representatives
    #
    # @return [void]
    def process_vsos_and_reps
      # Process VSOs first (must exist before representatives can reference them)
      update_vsos
      @report << "VSOs processed: #{@vso_ids.uniq.compact.size}\n"
      @ingestion_log&.mark_entity_success!(VSOS, count: @vso_ids.uniq.compact.size)

      # Process representatives
      update_reps
      @report << "Representatives processed: #{@representative_ids.uniq.compact.size} (deduplicated)\n"
      validate_rep_addresses
      @ingestion_log&.mark_entity_success!(REPRESENTATIVES, count: @representative_ids.uniq.compact.size)
    end

    # Marks organizations and representatives as failed
    #
    # @param error_message [String] The error message
    # @return [void]
    def mark_orgs_and_reps_failed(error_message)
      @ingestion_log&.mark_entity_failed!(REPRESENTATIVES, error: error_message)
      @ingestion_log&.mark_entity_failed!(VSOS, error: error_message)
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
    rescue => e
      @processing_error_types << entity_type unless @processing_error_types.include?(entity_type)
      log_error("Error updating #{entity_type}s: #{e.message}")
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
      @processing_error_types << VSOS unless @processing_error_types.include?(VSOS)
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
      @processing_error_types << REPRESENTATIVES unless @processing_error_types.include?(REPRESENTATIVES)
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
      @representative_ids_for_address_validation << record.id if record.raw_address != raw_address

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
                                  phone: rep['representative']['workNumber'],
                                  email: rep['representative']['workEmailAddress'],
                                  raw_address: raw_address_for_representative(rep),
                                  registration_number: rep.dig('representative', 'id')
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

    def processed_individual_types
      # Determine which individual types were processed based on force_update_types
      [AGENTS, ATTORNEYS, REPRESENTATIVES].filter_map do |type|
        ENTITY_CONFIG.public_send(type.downcase).individual_type if @force_update_types.include?(type)
      end
    end

    def remove_skipped_deletions
      # If @processing_error_types includes an entity type, we skip deletions for that type
      # by preloading the current IDs into the respective ID arrays.
      # Also skip deletions if processed counts don't match expected counts.

      # Validate all processed counts
      validate_all_counts

      individual_types = {
        AGENTS => :@agent_ids,
        ATTORNEYS => :@attorney_ids,
        REPRESENTATIVES => :@representative_ids
      }

      individual_types.each do |type, ivar|
        skip_due_to_error = @processing_error_types.include?(type)
        skip_due_to_mismatch = @count_mismatch_types.include?(type.to_sym)

        next unless skip_due_to_error || skip_due_to_mismatch

        ids = AccreditedIndividual.where(
          individual_type: ENTITY_CONFIG.send(type).individual_type
        ).pluck(:id)
        instance_variable_set(ivar, ids)
      end

      skip_vso_deletion = @processing_error_types.include?(VSOS) ||
                          @count_mismatch_types.include?(:veteran_service_organizations)
      @vso_ids = AccreditedOrganization.all.pluck(:id) if skip_vso_deletion
    end

    # Validates processed counts for all entity types against expected counts
    #
    # @return [void]
    def validate_all_counts
      entity_mappings = {
        agents: @agent_ids,
        attorneys: @attorney_ids,
        veteran_service_organizations: @vso_ids,
        representatives: @representative_ids
      }

      entity_mappings.each do |type_key, ids|
        next unless @expected_counts[type_key]

        counts_match_expected?(type_key.to_s, ids.uniq.compact.size)
      end
    end

    # Validates that the processed count matches the expected count within tolerance
    # Uses the same DECREASE_THRESHOLD as count validation to maintain consistency
    #
    # @param entity_type [String, Symbol] The type of entity to validate
    # @param processed_count [Integer] The number of records actually processed
    # @return [Boolean] true if counts match within tolerance, false otherwise
    def counts_match_expected?(entity_type, processed_count)
      entity_type = entity_type.to_sym
      expected_count = @expected_counts[entity_type]

      # If we don't have an expected count, we can't validate
      return true if expected_count.nil? || expected_count.zero?

      # If processed count is greater or equal to expected, that's fine
      return true if processed_count >= expected_count

      # Calculate percentage change (negative for decrease)
      change_percentage = ((processed_count - expected_count).to_f / expected_count)

      # Check if decrease is within acceptable threshold (DECREASE_THRESHOLD is negative, e.g., -0.20)
      within_tolerance = change_percentage > DECREASE_THRESHOLD

      # Track mismatch if outside tolerance
      unless within_tolerance
        @count_mismatch_types << entity_type unless @count_mismatch_types.include?(entity_type)
        percentage_display = (change_percentage * 100).round(2)
        log_error("Count mismatch for #{entity_type}: expected #{expected_count}, " \
                  "processed #{processed_count} (#{percentage_display}% change)")
      end

      within_tolerance
    end

    # Removes AccreditedIndividual records that are no longer present in the GCLAWS API
    # When force_update_types is specified, only deletes records of the processed types
    #
    # @return [void]
    def delete_removed_accredited_individuals
      # @force_update_types are only present when manually reprocessing entity types.  They aren't present in the
      # ordinary daily job run.
      if @force_update_types.any?
        # Only delete records of types that were actually processed

        # If no individual types were processed, return early to avoid deleting any records.
        # This safeguards against accidental deletion when no types were selected for processing.
        return if processed_individual_types.empty?

        # Delete only records of processed types that are not in the current ID lists
        AccreditedIndividual.where(individual_type: processed_individual_types)
                            .where.not(id: @agent_ids + @attorney_ids + @representative_ids)
                            .find_each do |record|
          record.destroy
        rescue => e
          log_error("Error deleting old accredited individual with ID #{record.id}: #{e.message}")
        end
      else
        # Original behavior: delete all records not in current ID lists
        AccreditedIndividual.where.not(id: @agent_ids + @attorney_ids + @representative_ids).find_each do |record|
          record.destroy
        rescue => e
          log_error("Error deleting old accredited individual with ID #{record.id}: #{e.message}")
        end
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
      instance_variable_get(config[:validation_ids_var]) << record.id if record.raw_address != raw_address

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
        last_name: entity['lastName']
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

    # Queues address validation jobs for a batch of record IDs
    #
    # @param record_ids_for_validation [Array<Integer>] Record IDs to validate
    # @param description [String] Description for the Sidekiq batch
    # @return [void]
    def validate_addresses(record_ids_for_validation,
                           description = 'Batching address updates from GCLAWS Accreditation API')
      return if record_ids_for_validation.empty?

      delay = 0
      batch = Sidekiq::Batch.new
      batch.description = description

      begin
        batch.jobs do
          record_ids_for_validation.uniq.each_slice(SLICE_SIZE) do |ids|
            RepresentationManagement::AccreditedIndividualsUpdate.perform_in(delay.minutes, ids)
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
      validation_ids_var = config[:validation_ids_var]
      description = config[:validation_description]

      validate_addresses(
        instance_variable_get(validation_ids_var),
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
      log_to_slack_channel("RepresentationManagement::AccreditedEntitiesQueueUpdates error: #{message}")
      Rails.logger.error("RepresentationManagement::AccreditedEntitiesQueueUpdates error: #{message}")
    end

    def log_to_slack_channel(message)
      return unless Settings.vsp_environment == 'production'

      slack_client = SlackNotify::Client.new(webhook_url: Settings.edu.slack.webhook_url,
                                             channel: '#benefits-representation-management-notifications',
                                             username: 'RepresentationManagement::AccreditationApiEntityCountBot')
      slack_client.notify(message)
    end

    def calculate_duration(start_time, end_time)
      total_seconds = (end_time - start_time).to_i
      hours = total_seconds / 3600
      minutes = (total_seconds % 3600) / 60
      seconds = total_seconds % 60

      if hours.positive?
        "#{hours}h #{minutes}m #{seconds}s"
      elsif minutes.positive?
        "#{minutes}m #{seconds}s"
      else
        "#{seconds}s"
      end
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

    # Helper method to delete records that are not in the specified ID list
    #
    # @param model_class [Class] The model class to operate on
    # @param id_list [Array<Integer>] The list of valid IDs
    # @param error_context [String] Context for error logging
    # @return [void]
    def delete_removed_records(model_class, id_list, error_context)
      model_class.where.not(id: id_list).find_each do |record|
        record.destroy
      rescue => e
        log_error("Error deleting old #{error_context} with ID #{record.id}: #{e.message}")
      end
    end

    # Removes AccreditedOrganization records that are no longer present in the GCLAWS API
    # When force_update_types is specified, only deletes when VSOs were processed
    #
    # @return [void]
    def delete_removed_accredited_organizations
      # Only delete VSO records if VSOs were processed or no force update specified
      if @force_update_types.empty? || @force_update_types.include?(VSOS)
        delete_removed_records(AccreditedOrganization, @vso_ids, 'accredited organization')
      end
    end

    # Removes Accreditation records that are no longer valid
    # When force_update_types is specified, only deletes when representatives or VSOs were processed
    #
    # @return [void]
    def delete_removed_accreditations
      # Only delete accreditation records if representatives or VSOs were processed or no force update specified
      if @force_update_types.empty? || @force_update_types.intersect?([REPRESENTATIVES, VSOS])
        delete_removed_records(Accreditation, @accreditation_ids, 'accreditation')
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

    # Completes the ingestion log with overall metrics
    def complete_ingestion_log
      return unless @ingestion_log

      @ingestion_log.complete_ingestion!(
        agents: @agent_ids.uniq.compact.size,
        attorneys: @attorney_ids.uniq.compact.size,
        representatives: @representative_ids.uniq.compact.size,
        veteran_service_organizations: @vso_ids.uniq.compact.size,
        accreditations: @accreditation_ids.uniq.compact.size
      )
    end

    # Marks the ingestion log as failed
    #
    # @param error_message [String] The error message to log
    def fail_ingestion_log(error_message)
      return unless @ingestion_log

      @ingestion_log.fail_ingestion!(error: error_message)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
