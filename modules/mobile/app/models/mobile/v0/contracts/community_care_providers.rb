# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class CommunityCareProviders < PaginationBase
        params do
          optional(:facility_id).maybe(:string, :filled?)
          optional(:service_type).maybe(:string, :filled?)
        end
      end
    end
  end
end
