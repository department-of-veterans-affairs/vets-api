# frozen_string_literal: true

require 'vets/model'

module FacilitiesApi
  module V2
    module PPMS
      class Response
        include Vets::Model

        attribute :body, Hash, array: true
        attribute :current_page, Integer
        attribute :per_page, Integer
        attribute :offset, Integer
        attribute :total_entries, Integer

        def initialize(response, params = {})
          super()

          @body = response.body.fetch('value')

          @current_page = Integer(response.body['PageNumber'] || params[:page] || 1)
          @per_page =     Integer(response.body['PageSize'] || params[:per_page] || 10)
          @total_entries = Integer(response.body['TotalResults'] || (current_page * per_page))

          trim_response_attributes!
        end

        def providers
          providers = body.map do |attr|
            provider = if attr.key?('ProviderServices')
                         FacilitiesApi::V2::PPMS::Provider.new(attr['ProviderServices'].first)
                       else
                         FacilitiesApi::V2::PPMS::Provider.new(attr)
                       end
            provider.set_hexdigest_as_id!
            provider
          end.uniq(&:id)

          paginate_response(providers)
        end

        def places_of_service
          providers = body.map do |attr|
            provider = if attr.key?('ProviderServices')
                         FacilitiesApi::V2::PPMS::Provider.new(attr['ProviderServices'].first)
                       else
                         FacilitiesApi::V2::PPMS::Provider.new(attr)
                       end
            provider.set_hexdigest_as_id!
            provider.set_group_practice_or_agency!
            provider
          end.uniq(&:id)

          paginate_response(providers)
        end

        def specialties
          body.map do |attr|
            FacilitiesApi::V2::PPMS::Specialty.new(attr)
          end
        end

        private

        def trim_response_attributes!
          body.collect! do |hsh|
            hsh.each_pair.to_h do |attr, value|
              if value.is_a? String
                [attr, value.gsub(/ +/, ' ').strip]
              else
                [attr, value]
              end
            end
          end
        end

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
