# frozen_string_literal: true

module Mobile
  module V0
    module Claims
      class Proxy
        STATSD_UPLOAD_LATENCY = 'mobile.api.claims.upload.latency'

        def initialize(user)
          @user = user
        end

        def get_appeal(id)
          appeals = appeals_service.get_appeals(@user).body['data']
          appeal = appeals.filter { |entry| entry['id'] == id }[0]
          raise Common::Exceptions::RecordNotFound, id unless appeal

          serializable_resource = OpenStruct.new(appeal['attributes'])
          serializable_resource[:id] = appeal['id']
          serializable_resource[:type] = appeal['type']
          serializable_resource
        rescue => e
          raise if e.is_a?(Common::Exceptions::RecordNotFound)

          handle_middleware_error(e)
        end

        def get_all_appeals
          lambda {
            begin
              { list: appeals_service.get_appeals(@user).body['data'], errors: nil }
            rescue => e
              { list: nil, errors: Mobile::V0::Adapters::ClaimsOverviewErrors.new.parse(e, 'appeals') }
            end
          }
        end

        private

        def appeals_service
          @appeals_service ||= Caseflow::Service.new
        end

        def handle_middleware_error(error)
          response_values = {
            details: error.details
          }
          raise Common::Exceptions::BackendServiceException.new('MOBL_502_upstream_error', response_values, 500,
                                                                error.body)
        end
      end
    end
  end
end
