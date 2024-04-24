# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    module ServiceAction
      class Definition < Data.define(:service, :action)
        Service = Data.define(:path, :namespaces)
        Action = Data.define(:name)

        class ManageRepresentativeService < Service
          include Singleton

          def initialize
            super(
              path: 'VDC/ManageRepresentativeService',
              namespaces: { 'data' => '/data' }
            )
          end

          class ReadPoaRequest < Definition
            include Singleton

            def initialize
              super(
                service: ManageRepresentativeService.instance,
                action: Action.new(name: 'readPOARequest'),
              )
            end
          end
        end
      end
    end
  end
end
