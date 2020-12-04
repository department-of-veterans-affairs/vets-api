# frozen_string_literal: true

module Mobile
  module V0
    module Profile
      class IncompleteTransaction < StandardError; end
      
      class SynchronousUpdateService
        def initialize(user)
          @user = user
        end
        
        def save_and_await_response(resource_type:, params:, update: true)
          http_method = update ? 'put' : 'post'
          initial_transaction = save(http_method, resource_type, params)
          binding.pry
          return initial_transaction if AsyncTransaction::Vet360::Base::FINAL_STATUSES.include?(initial_transaction.status)
          transaction_id = initial_transaction.transaction_id
          
          poll_with_backoff do
            check_transaction_status!(transaction_id)
          end
        end
        
        private
        
        def save(http_method, resource_type, params)
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
        
        def contact_information_service
          Vet360::ContactInformation::Service.new(@user)
        end
        
        def check_transaction_status!(transaction_id)
          transaction = AsyncTransaction::Vet360::Base.refresh_transaction_status(
            @user,
            contact_information_service,
            transaction_id
          )

          raise Common::Exceptions::RecordNotFound, transaction unless transaction
          binding.pry
          transaction
        end
        
        def poll_with_backoff
          start = Time.now.utc.to_i
          tries = 0
          begin
            yield
          rescue IncompleteTransaction
            tries += 1
            puts tries
            now = Time.now.utc.to_i
            elapsed = now - start
            raise "Giving up" if elapsed >= 10
            # sleep with exponential backoff,
            # retry at most (depending on service latency) 10 times over 10 seconds
            sleep Float(2.75 ** tries) / 1000
            retry
          end
        end
      end
    end
  end
end
