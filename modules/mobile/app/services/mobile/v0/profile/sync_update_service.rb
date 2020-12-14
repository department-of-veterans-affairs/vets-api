# frozen_string_literal: true

module Mobile
  module V0
    module Profile
      class IncompleteTransaction < StandardError; end

      # Provides a syncronous alternative to the Vet360 async profile updates
      # so that mobile app can limit the number of HTTP requests needed to perform
      # a profile update.
      #
      # @example save new parameters and wait for a response
      #   service = Mobile::V0::Profile::SyncUpdateService.new(user)
      #   response = service.save_and_await_response('address', update_params)
      #
      class SyncUpdateService
        TRANSACTION_RECEIVED = 'RECEIVED'
        TIMEOUT_SECONDS = 55

        def initialize(user)
          @user = user
        end

        # Kicks off an update and polls to check for a complete response.
        # This method will raise a timeout if it hit 10 retries or the 55s
        # limit (whichever comes first).
        #
        # @resource_type String the resource type to update
        # @params Hash the new parameters used in the update
        # @update whether the save is a new write or an update
        #
        # @return AsyncTransaction::Vet360::Base the final async transaction status
        #
        def save_and_await_response(resource_type:, params:, update: false)
          http_method = update ? 'put' : 'post'
          initial_transaction = save!(http_method, resource_type, params)

          # return non-received status transactions (errors)
          return initial_transaction unless initial_transaction.transaction_status == TRANSACTION_RECEIVED

          poll_with_backoff do
            check_transaction_status!(initial_transaction.transaction_id)
          end
        end

        private

        def save!(http_method, resource_type, params)
          record = build_record(resource_type, params)
          raise Common::Exceptions::ValidationErrors, record unless record.valid?

          response = contact_information_service.send("#{http_method}_#{resource_type.downcase}", record)
          "AsyncTransaction::Vet360::#{resource_type.capitalize}Transaction".constantize.start(@user, response)
        end

        def build_record(type, params)
          "Vet360::Models::#{type.capitalize}"
            .constantize
            .new(params)
            .set_defaults(@user)
        end

        def poll_with_backoff
          try = 0
          start = Time.now.utc.to_i
          begin
            yield
          rescue IncompleteTransaction
            # tries 5 times over the first roughly five seconds, then five more times over the next 50s
            #   +
            #   |
            #   |                                                25.6
            # t |                              12.8
            # r |                    6.4
            # i |             3.2
            # e |        1.6
            # s |     0.8
            #   |   0.4
            #   | 0.2
            #   |0.1
            #   +--------------------------------------------------+
            #   0  1   2   4   7       15         25             50
            #                     total seconds
            #
            next_try_seconds = Float(2**try) / 10
            elapsed = seconds_elapsed_since(start)
            log_incomplete(elapsed, next_try_seconds, try)

            # raise gateway timeout if we're at try number 10 or if the next retry would fall outside the timeout window
            raise_timeout_error(elapsed, try) if tries_or_time_exhausted?(next_try_seconds, elapsed, try)

            sleep next_try_seconds
            try += 1
            retry
          end
        end

        def seconds_elapsed_since(start)
          Time.now.utc.to_i - start
        end

        def tries_or_time_exhausted?(sleep_duration, elapsed, try)
          try == 9 || elapsed + sleep_duration > TIMEOUT_SECONDS
        end

        def check_transaction_status!(transaction_id)
          @transaction_id = transaction_id

          transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(
            @user,
            contact_information_service,
            transaction_id
          )

          raise Common::Exceptions::RecordNotFound, transaction unless transaction
          raise IncompleteTransaction unless transaction.finished?

          Rails.logger.info(
            'mobile syncronous profile update complete',
            transaction_id: @transaction_id
          )

          transaction
        end

        def contact_information_service
          Vet360::ContactInformation::Service.new @user
        end

        def raise_timeout_error(elapsed, try)
          Rails.logger.error(
            'mobile syncronous profile update timeout',
            transaction_id: @transaction_id, try: try, elapsed: elapsed
          )
          raise Common::Exceptions::GatewayTimeout
        end

        def log_incomplete(elapsed, next_try_seconds, try)
          Rails.logger.info(
            'mobile syncronous profile update not yet complete',
            transaction_id: @transaction_id, try: try, seconds_until_retry: next_try_seconds, elapsed: elapsed
          )
        end
      end
    end
  end
end
