# frozen_string_literal: true

module Common
  module Client
    module Concerns
      ##
      # Module mixin for overriding session logic when making session-based client connections that
      # should lock during session creation, to prevent threads from making simultaneous
      # authentication API calls.
      #
      # All references to "session" in this module refer to the upstream MHV session.
      #
      # @see MedicalRecords::Client
      #
      # @!attribute [r] session
      #   @return [Hash] a hash containing session information
      #
      module MhvLockedSessionClient
        extend ActiveSupport::Concern
        include SentryLogging

        LOCK_RETRY_DELAY = 0.3 # Number of seconds to wait between attempts to acquire a session lock
        RETRY_ATTEMPTS = 40 # How many times to attempt await of acquiring a session lock by a preceding request

        attr_reader :session

        ##
        # @param session [Hash] a hash containing a key with which the session will be found or built
        #
        def initialize(session:)
          refresh_session(session)
        end

        ##
        # Ensure the upstream MHV session is not expired or incomplete.
        #
        # @return [MhvFhirSessionClient] instance of `self`
        #
        def authenticate
          raise 'A user_key is required for session creation' unless user_key

          iteration = 0

          # Loop unless a complete, valid MHV session exists, or until max_iterations is reached
          while invalid?(session) && iteration < RETRY_ATTEMPTS
            break if lock_and_get_session # Break out of the loop once a new session is created.

            sleep(LOCK_RETRY_DELAY)

            # Refresh the MHV session reference in case another thread has updated it.
            refresh_session(session)
            iteration += 1
          end
          if invalid?(session) && iteration >= RETRY_ATTEMPTS
            Rails.logger.info("Failed to create #{@client_session} after #{iteration} attempts to acquire lock")
          end

          self
        end

        ##
        # Override client_session method to use extended ::ClientSession classes
        #
        class_methods do
          ##
          # @return [MedicalRecords::ClientSession] if a MR (Medical Records) client session
          # @return [Rx::ClientSession] if an Rx (Prescription) client session
          # @return [SM::ClientSession] if a SM (Secure Messaging) client session
          #
          def client_session(klass = nil)
            @client_session ||= klass
          end
        end

        protected

        def refresh_session(session)
          @session = self.class.client_session.find_or_build(session)
        end

        def invalid?(session)
          session.expired?
        end

        private

        ##
        # Attempt to acquire a redis lock, then create a new MHV session. Once the session is created,
        # release the lock.
        #
        # return [Boolean] true if a session was created, otherwise false
        #
        def lock_and_get_session
          redis_lock = obtain_redis_lock
          if redis_lock
            begin
              @session = get_session
              return true
            ensure
              release_redis_lock(redis_lock)
            end
          end
          false
        end

        def obtain_redis_lock
          lock_key = "mhv_session_lock:#{user_key}"
          redis_lock = Redis::Namespace.new(REDIS_CONFIG[session_config_key][:namespace], redis: $redis)
          success = redis_lock.set(lock_key, 1, nx: true, ex: REDIS_CONFIG[session_config_key][:each_ttl])

          return redis_lock if success

          nil
        end

        def release_redis_lock(redis_lock)
          lock_key = "mhv_session_lock:#{user_key}"
          redis_lock.del(lock_key)
        end
      end
    end
  end
end
