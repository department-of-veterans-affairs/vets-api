# frozen_string_literal: true

module ThirdPartyTransactionLogging
  extend ActiveSupport::Concern

  module MethodWrapper
    # @method_names
    #   - Array (of /or single) method name(s). e.g. ['method_1', :method_2]
    # @additional_logs
    #   - Will add to and / or overwrite the default data with usecase specific
    #     log data
    def wrap_with_logging(*method_names, additional_logs: {})
      # including the instance method helpers inside this method makes them
      # available on the instance with access to the controllers scope (e.g.
      # current_user)
      include(ScopedInstanceMethods)

      proxy = Module.new do
        method_names.each do |method_name|
          # define patchable method(s) with the same name inside of a proxy module.
          define_method(method_name) do |*args, &block|
            log_3pi_begin(additional_logs)
            # delegate to the original behavior
            super(*args, &block)
            log_3pi_complete(additional_logs)
          end
        end
      end
      # prepend the proxy module, allowing both our wrapped version to run
      # logging as well as delegating to the original.
      prepend(proxy)
    end
  end

  # these will be included after instance instantiation, making them available
  # to the instance and retaining their scope.
  module ScopedInstanceMethods
    def log_3pi_begin(additional_logs = {})
      @start_time = Time.current

      log = {
        process_id: Process.pid,
        user_uuid: current_user.try(:account_uuid),
        action: 'Begin interaction with 3rd party API',
        breadcrumbs: "#{File.basename(__FILE__)}, #{self.class}##{__method__}",
        start_time: @start_time
      }.merge(additional_logs)

      Rails.logger.info(log)
    rescue => e
      Rails.logger.error(e)
    end

    def log_3pi_complete(additional_logs = {})
      now = Time.current

      log = {
        process_id: Process.pid,
        user_uuid: current_user.try(:account_uuid),
        action: 'Complete interaction with 3rd party API',
        breadcrumbs: "#{File.basename(__FILE__)}, #{self.class}##{__method__}",
        upload_duration: (now - @start_time).to_f,
        end_time: now
      }.merge(additional_logs)

      Rails.logger.info(log)
    rescue => e
      Rails.logger.error(e)
    end
  end
end
