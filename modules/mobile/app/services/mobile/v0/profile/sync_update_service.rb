# frozen_string_literal: true

module Mobile
  module V0
    module Profile
      class IncompleteTransaction < StandardError; end

      class SyncUpdateService
        TRANSACTION_RECEIVED = 'RECEIVED'
        TIMEOUT_SECONDS = 55

        def initialize(user)
          @user = user
          @transaction_id = nil
        end

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
          start = seconds_since_epoch
          begin
            yield
          rescue IncompleteTransaction
            # tries 5 times over the first roughly five seconds, then five more times over the next 50s
            next_try_seconds = Float(2**try) / 10
            elapsed = get_elapsed(start)
            log_incomplete(elapsed, next_try_seconds, try)

            # raise gateway timeout if we're at try number 10 or if the next retry would fall outside the timeout window
            raise_timeout_error(elapsed, try) if tries_or_time_exhausted?(next_try_seconds, elapsed, try)

            sleep next_try_seconds
            try += 1
            retry
          end
        end

        def get_elapsed(start)
          seconds_since_epoch - start
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

        def seconds_since_epoch
          Time.now.utc.to_i
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
