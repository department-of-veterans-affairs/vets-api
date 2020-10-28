# frozen_string_literal: true

require 'common/models/base'

module Facilities
  module PPMS
    module V1
      class Response < Common::Base
        attribute :body, String
        attribute :params, Hash
        attribute :current_page, Integer
        attribute :per_page, Integer
        attribute :offset, Integer
        attribute :total_entries, Integer

        def initialize(body, params = {})
          super()
          self.body = body
          self.params = params
          self.current_page = Integer(params[:page] || 1)
          self.per_page = Integer(params[:per_page] || 10)
          self.offset = (current_page - 1) * per_page
          self.total_entries = current_page * per_page + 1
        end

        def providers
          providers = body[offset, per_page].map do |attr|
            ::PPMS::Provider.new(attr)
          end.uniq(&:id)

          paginate_response(providers)
        end

        def places_of_service
          providers = body[offset, per_page].map do |attr|
            provider = ::PPMS::Provider.new(attr)
            provider.set_hexdigest_as_id!
            provider.set_group_practive_or_agency!
            provider
          end.uniq(&:id)

          paginate_response(providers)
        end

        def provider
          ::PPMS::Provider.new(body)
        end

        private

        def paginate_response(providers)
          WillPaginate::Collection.create(current_page, per_page) do |pager|
            pager.replace(providers)
            pager.total_entries = total_entries
          end
        end
      end
    end
  end
end
