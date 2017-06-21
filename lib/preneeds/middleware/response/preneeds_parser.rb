# frozen_string_literal: true
module Preneeds
  module Middleware
    module Response
      # class responsible for customizing parsing
      class PreneedsParser < Faraday::Response::Middleware
        PARSE_LIST = [
          :parsed_cemetery_list, :parsed_states_list, :attachment_types_list, :discharge_types_list,
          :attachment_types_list, :branches_of_service_list, :military_rank_for_branch_of_service_list
        ].freeze

        def on_complete(env)
          return unless env.response_headers['content-type'] =~ /\bjson/
          env[:body] = parse(env.body) unless env.body.blank?
        end

        def parse(body)
          @parsed_json = body

          data = PARSE_LIST.each do |meth|
            results = send(meth)
            break results if results.present?
          end

          @parsed_json = { data: data }
        end

        def parsed_cemetery_list
          @parsed_json.keys.include?(:cemeteries) ? @parsed_json[:cemeteries] : nil
        end

        def parsed_states_list
          @parsed_json.keys.include?(:states) ? @parsed_json[:states] : nil
        end

        def discharge_types_list
          @parsed_json.keys.include?(:discharge_types) ? @parsed_json[:discharge_types] : nil
        end

        def attachment_types_list
          @parsed_json.keys.include?(:attachment_types) ? @parsed_json[:attachment_types] : nil
        end

        def branches_of_service_list
          @parsed_json.keys.include?(:branches_of_service) ? @parsed_json[:branches_of_service] : nil
        end

        def military_rank_for_branch_of_service_list
          return nil unless @parsed_json.keys.include?(:military_rank_for_branch_of_service) &&
                            @parsed_json[:military_rank_for_branch_of_service].present?

          @parsed_json[:military_rank_for_branch_of_service].each do |r|
            r[:military_rank_detail] = r.delete(:id)
          end

          @parsed_json[:military_rank_for_branch_of_service]
        end
      end
    end
  end
end

Faraday::Response.register_middleware preneeds_parser: Preneeds::Middleware::Response::PreneedsParser
