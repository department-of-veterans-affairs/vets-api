# frozen_string_literal: true

module Common
  module Client
    module Concerns
      ##
      # Module mixin for overriding session logic when making session-based client connections that
      # should lock during session creation, to prevent threads from making simultaneous
      # authentication API calls.
      #
      # All refrences to "session" in this module refer to the upstream MHV session.
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
        RETRY_ATTEMPTS = 30 # How many times to attempt to acquire a session lock

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
          raise 'ICN is required for session creation' unless user_key

          # iteration = 0
          puts "session.expired: #{session.expired?}"
          # return self if !session.expired?
          attempts = 0
          # max_attempts = 10  # Set this to the maximum number of attempts you want to allow
          
          while session.expired? && attempts <= RETRY_ATTEMPTS

              puts "redis_key.exists?(lock_key): #{redis_key.exists?(lock_key)}"
              if redis_key.exists?(lock_key)
                attempts += 1
                raise "Max attempts exceeded" if attempts > RETRY_ATTEMPTS

                sleep(LOCK_RETRY_DELAY) # Wait for a short time before retrying

                puts "refresh session"
                refresh_session(session)
              else
                lock_and_get_session
                break
              end
            
          end

          # # Loop unless a complete, valid MHV session exists, or until max_iterations is reached
          # while invalid?(session) 
          #   puts "session is invalid"
          #   while iteration < RETRY_ATTEMPTS
          #     break if lock_and_get_session # Break out of the loop once a new session is created.

          #     sleep(LOCK_RETRY_DELAY)

          #     # Refresh the MHV session reference in case another thread has updated it.
          #     refresh_session(session)
          #     iteration += 1
          #   end
          # end
          if invalid?(session) && attempts >= RETRY_ATTEMPTS
            Rails.logger.info("Failed to create #{@client_session} after #{attempts} attempts to acquire lock")
          end

          self
        end

        ##
        # Override client_session method to use extended ::ClientSession classes
        #
        class_methods do
          ##
          # @return [MedicalRecords::ClientSession] if a MR (Medical Records) client session
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
          puts "lock_and_get_session redis_lock: #{redis_lock}"
          if redis_lock
            begin
              @session = get_session
              @session.save
              return true
            ensure
              release_redis_lock
            end
          end
          false
        end

        def redis_key
          Redis::Namespace.new(REDIS_CONFIG[session_config_key][:namespace], redis: $redis)
        end

        def lock_key
          lock_key = "mhv_session_lock:#{user_key}"
        end

        def obtain_redis_lock
          puts "obtain_redis_lock"
          # lock_key = "mhv_session_lock:#{user_key}"
          # redis_lock = Redis::Namespace.new(REDIS_CONFIG[session_config_key][:namespace], redis: $redis)
          # puts "Lock exists: #{redis_key.exists?(lock_key)}"  # Add this line
          # success = redis_key.set(lock_key, 1, nx: true, ex: REDIS_CONFIG[session_config_key][:each_ttl])
          redis_key.set(lock_key, 1, nx: true, ex: REDIS_CONFIG[session_config_key][:each_ttl])
          # return redis_lock if success

          # nil
        end

        def release_redis_lock
          puts "release_redis_lock"
          # lock_key = "mhv_session_lock:#{user_key}"
          redis_key.del(lock_key)
        end
      end
    end
  end
end
