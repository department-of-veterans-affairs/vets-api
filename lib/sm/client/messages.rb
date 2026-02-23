# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Module containing message retrieval and management methods for the SM Client
    #
    module Messages
      ##
      # Get message categories
      #
      # @return [Category]
      #
      def get_categories
        path = 'message/category'

        json = perform(:get, path, nil, token_headers).body
        Category.new(json[:data])
      end

      ##
      # Get a message
      #
      # @param id [Fixnum] message id
      # @return [Message]
      #
      def get_message(id)
        path = "message/#{id}/read"
        json = perform(:get, path, nil, token_headers).body
        message = Message.new(json[:data].merge(json[:metadata]))

        # Derive OH migration phase from cached triage teams
        message.oh_migration_phase = derive_oh_migration_phase_for_message(message)
        message.migrated_to_oracle_health = derive_migrated_to_oracle_health(message)
        message
      end

      ##
      # Get a message thread old api
      #
      # @param id [Fixnum] message id
      # @return [Common::Collection[Message]]
      #
      def get_message_history(id)
        path = "message/#{id}/history"
        json = perform(:get, path, nil, token_headers).body
        Vets::Collection.new(json[:data], Message, metadata: json[:metadata], errors: json[:errors])
      end

      ##
      # Get a message thread
      #
      # @param id [Fixnum] message id
      # @return [Common::Collection[MessageThread]]
      #
      def get_messages_for_thread(id)
        path = "message/#{id}/messagesforthread"
        path = append_requires_oh_messages_query(path)

        json = perform(:get, path, nil, token_headers).body
        is_oh = json[:data].any? { |msg| msg[:is_oh_message] == true }
        result = Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata],
                                                                         errors: json[:errors])
        track_metric('get_messages_for_thread', is_oh:, status: 'success')
        result
      rescue => e
        track_metric('get_messages_for_thread', is_oh: false, status: 'failure')
        raise e
      end

      ##
      # Get a message thread with full body and attachments
      #
      # @param id [Fixnum] message id
      # @return [Common::Collection[MessageThreadDetails]]
      #
      def get_full_messages_for_thread(id)
        path = "message/#{id}/allmessagesforthread/1"
        path = append_requires_oh_messages_query(path)
        json = perform(:get, path, nil, token_headers).body
        is_oh = json[:data].any? { |msg| msg[:is_oh_message] == true }
        result = Vets::Collection.new(json[:data], MessageThreadDetails, metadata: json[:metadata],
                                                                         errors: json[:errors])

        # Derive OH migration phase from cached triage teams
        oh_migration_phase = derive_oh_migration_phase(result)
        result.data.each { |msg| msg.oh_migration_phase = oh_migration_phase } if oh_migration_phase

        # Derive migrated_to_oracle_health for each message based on its triage_group
        result.data.each { |msg| msg.migrated_to_oracle_health = derive_migrated_to_oracle_health(msg) }

        track_metric('get_full_messages_for_thread', is_oh:, status: 'success')
        result
      rescue => e
        track_metric('get_full_messages_for_thread', is_oh: false, status: 'failure')
        raise e
      end

      ##
      # Move a message to a given folder
      #
      # @param id [Fixnum] the {Message} id
      # @param folder_id [Fixnum] the {Folder} id
      # @return [Fixnum] the response status code
      #
      def post_move_message(id, folder_id)
        custom_headers = token_headers.merge('Content-Type' => 'application/json')
        response = perform(:post, "message/#{id}/move/tofolder/#{folder_id}", nil, custom_headers)

        response&.status
      end

      ##
      # Move a thread to a given folder
      #
      # @param id [Fixnum] the thread id
      # @param folder_id [Fixnum] the {Folder} id
      # @return [Fixnum] the response status code
      #
      def post_move_thread(id, folder_id)
        custom_headers = token_headers.merge('Content-Type' => 'application/json')
        response = perform(:post, "message/#{id}/movethreadmessages/tofolder/#{folder_id}", nil, custom_headers)
        response&.status
      end

      ##
      # Delete a message
      #
      # @param id [Fixnum] id of message to be deleted
      # @return [Fixnum] the response status code
      #
      def delete_message(id)
        custom_headers = token_headers.merge('Content-Type' => 'application/json')
        response = perform(:post, "message/#{id}", nil, custom_headers)

        response&.status
      end

      private

      ##
      # Derives OH migration phase for a single message based on its triage_group_id
      #
      # @param message [Message] the message to derive phase for
      # @return [String, nil] current migration phase (e.g., "p1"), or phase of soonest migration window
      #                       if team not found in cache, or nil if no migration data exists
      #
      def derive_oh_migration_phase_for_message(message)
        triage_group_id = message&.triage_group_id
        return nil if triage_group_id.blank?

        oh_service = MHV::OhFacilitiesHelper::Service.new(current_user)

        # Look up station_number from cached triage teams
        cached_teams = get_triage_teams_station_numbers
        return nil if cached_teams.blank?

        matching_team = cached_teams.find { |team| team.triage_team_id == triage_group_id }
        station_number = matching_team&.station_number
        return nil if station_number.blank?

        # Look up migration phase for this station number
        oh_service.get_phase_for_station_number(station_number)
      rescue => e
        Rails.logger.error(
          'Error deriving OH migration phase',
          { error_class: e.class.name, error_message: e.message, message_id: message&.id }
        )
        nil
      end

      ##
      # Determines if the message relates to a post-migration Oracle Health state.
      # A message is considered post-migration when the triage group's station_number
      # matches a facility in the veteran's VA profile that is marked as Cerner (isCerner),
      # but the triage group in a message is not an OH triage group (oh_triage_group is false).
      #
      # @param message [Message] the message to check
      # @return [Boolean] true if the message is in a post-migration state
      #
      def derive_migrated_to_oracle_health(message)
        triage_group = message&.triage_group
        return false if triage_group.blank?

        station_number = (triage_group[:station_number] || triage_group['station_number'])&.to_s
        oh_triage_group = if triage_group.key?(:oh_triage_group)
                            triage_group[:oh_triage_group]
                          else
                            triage_group['oh_triage_group']
                          end
        return false if station_number.blank?

        # Post-migration: facility is Cerner in VA profile but triage group is not yet OH
        cerner_facility_ids = current_user&.cerner_facility_ids || []
        cerner_facility_ids.include?(station_number) && oh_triage_group == false
      rescue => e
        Rails.logger.error(
          'Error deriving migrated_to_oracle_health',
          { error_class: e.class.name, error_message: e.message, message_id: message&.id }
        )
        false
      end

      ##
      # Derives OH migration phase from cached triage teams based on the first message's triage_group_id
      #
      # @param result [Vets::Collection] collection of MessageThreadDetails
      # @return [String, nil] current migration phase (e.g., "p1"), or phase of soonest migration window
      #                       if team not found in cache, or nil if no migration data exists
      #
      def derive_oh_migration_phase(message_thread_collection)
        return nil if message_thread_collection.data.blank?

        first_message = message_thread_collection.data.first
        derive_oh_migration_phase_for_message(first_message)
      end
    end
  end
end
