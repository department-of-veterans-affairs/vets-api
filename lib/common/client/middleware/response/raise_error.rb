module Common
  module Client
    module Middleware
      module Response
        class RaiseError < Faraday::Response::Middleware
          def on_complete(env)
            unless env.success?
              raise Common::Client::Errors::ClientResponse.new(env.status.to_i, env[:body])
            end  
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware raise_error: Common::Client::Middleware::Response::RaiseError
