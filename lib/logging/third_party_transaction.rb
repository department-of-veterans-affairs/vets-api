# frozen_string_literal: true

module Logging
  module ThirdPartyTransaction
    module MethodWrapper
      # @method_names
      #   - Array (of /or single) method name(s). e.g. ['method_1', :method_2]
      # @additional_class_logs
      #   - Will add to and / or overwrite the default data with usecase specific
      #     log data
      #   - scoped to the class, will be available at instantiation
      #   - [ KEY ]: log identifier, [ VALUE ]: log value
      # @additional_instance_logs
      #   - Will add to and / or overwrite the default data with usecase specific
      #     log data
      #   - scoped to the class, will be available at instantiation
      #   - [ KEY ]: log identifier, [ VALUE ]: method chain to access desired instance value
      #     - passed as an array, e.g. [:foo, :bar] will be calles as <instance>.foo.bar
      #     - will fail silently and return nil if methods or values are not available
      def wrap_with_logging(*method_names, additional_class_logs: {}, additional_instance_logs: {})
        # including the instance method helpers inside this method makes them
        # available on the instance with access to the current scope, (e.g.
        # current_user at the controller level)
        include(ScopedInstanceMethods)

        proxy = Module.new do
          method_names.each do |method_name|
            # define patchable method(s) with the same name inside of a proxy module.
            define_method(method_name) do |*args, &block|
              str_args = args.to_s
              log_3pi_begin(method_name, additional_class_logs, additional_instance_logs, str_args)
              # delegate to the original behavior
              result = super(*args, &block)
              log_3pi_complete(method_name, additional_class_logs, additional_instance_logs, str_args)
              result
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
      def log_3pi_begin(method_name, additional_class_logs, additional_instance_logs, args)
        @start_time = Time.current

        log = {
          process_id: Process.pid,
          user_uuid: try(:current_user).try(:account_uuid),
          action: 'Begin interaction with 3rd party API',
          wrapped_method: "#{self.class}##{method_name}",
          start_time: @start_time.to_s,
          passed_args: args
        }.merge(additional_class_logs).merge(parse_instance_logs(additional_instance_logs))

        Rails.logger.info(log)
      rescue => e
        Rails.logger.error(e)
      end

      def log_3pi_complete(method_name, additional_class_logs, additional_instance_logs, args)
        now = Time.current

        log = {
          process_id: Process.pid,
          user_uuid: try(:current_user).try(:account_uuid),
          action: 'Complete interaction with 3rd party API',
          wrapped_method: "#{self.class}##{method_name}",
          upload_duration: (now - @start_time).to_f,
          end_time: now.to_s,
          passed_args: args.to_s
        }.merge(additional_class_logs).merge(parse_instance_logs(additional_instance_logs))

        Rails.logger.info(log)
      rescue => e
        Rails.logger.error(e)
      end

      def parse_instance_logs(additional_instance_logs)
        # call method chains on instance and return a hash of values, e.g.
        # HAPPY PATH (where my_instance.user_account.id == s0meUs3r-Id-V@Lu3')
        # { user_uuid: [:user_account, :id] }
        # will be translated to
        # { user_uuid: 's0meUs3r-Id-V@Lu3' }
        #
        # or
        #
        # SAD PATH (safe)
        # { user_uuid: [:user_account, :id, :non_working_method, :something_else_that_breaks] }
        # will be translated to
        # { user_uuid: nil }
        {}.tap do |obj|
          additional_instance_logs.each do |key, method_chain|
            # using :try ensures we can fail quietly
            obj[key] = method_chain.inject(self, :try)
          end
        end
      end
    end
  end
end
