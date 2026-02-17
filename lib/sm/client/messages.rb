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
        if cached_teams.blank?
          # If no cached teams, return phase of soonest migration window (or nil if none exist)
          return oh_service.get_soonest_migration_phase
        end

        matching_team = cached_teams.find { |team| team.triage_team_id == triage_group_id }
        station_number = matching_team&.station_number
        if station_number.blank?
          # Team not found in cache, return phase of soonest migration window
          return oh_service.get_soonest_migration_phase
        end

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
