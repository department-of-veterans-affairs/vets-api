# frozen_string_literal: true

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Representative < Veteran::Service::Base
      self.primary_key = :representative_id

      def self.reload!
        fetch_data('orgsexcellist.asp')
      end
    end
  end
end
