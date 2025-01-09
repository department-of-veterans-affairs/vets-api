# frozen_string_literal: true

module ClaimsApi
  class PowerOfAttorneyRequest
    class Summary
      module Search
        class << self
          def perform(query) # rubocop:disable Metrics/MethodLength
            total_count = 0
            poa_requests = []

            begin
              action =
                BGSClient::Definitions::
                  ManageRepresentativeService::
                  ReadPoaRequest::
                  DEFINITION

              result =
                BGSClient.perform_request(action) do |xml, data_aliaz|
                  Query.dump(query, xml, data_aliaz)
                end

              total_count = result['totalNbrOfRecords'].to_i

              poa_requests = Array.wrap(result['poaRequestRespondReturnVOList'])
              poa_requests.map! { |data| Load.perform(data) }
            rescue BGSClient::Error::BGSFault => e
              # Sometimes this empty result is for valid reasons, i.e. a filter
              # combination that just happens to have no records. Other times it
              # is due to something like a non-existent POA code, which is an
              # invalid request from the client. But the BGS response looks the
              # same in either case so we can't distinguish between them.
              #
              # We could possibly make more requests to make that determination if
              # we find ourselves in this branch. But if we want to consider a
              # mixture of valid and invalid POA codes to be a valid request the
              # way BGS does, we'd have to check every POA code we were given.
              reason = e.detail.dig('MessageException', 'reason')
              raise unless reason == 'NO_RECORD_FOUND'
            end

            [
              total_count,
              poa_requests
            ]
          end
        end
      end
    end
  end
end