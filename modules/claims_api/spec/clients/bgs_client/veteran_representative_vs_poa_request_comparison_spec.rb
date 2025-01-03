# frozen_string_literal: true

require 'rails_helper'
require Rails.root / 'modules/claims_api/spec/rails_helper'
require 'bgs_service/veteran_representative_service'

RSpec.describe 'VeteranRepresentative versus POARequest comparison', :bgs do # rubocop:disable RSpec/DescribeClass
  it 'concerns the same underlying data' do
    skip 'refactor needed'

    use_soap_cassette('results', use_spec_name_prefix: true) do
      participant_ids = Set[]
      comparisons =
        Hash.new do |h_a, k_a|
          h_a[k_a] = Hash.new do |h_b, k_b|
            h_b[k_b] = {}
          end
        end

      page_number = 1
      page_size = 100

      # Suspicious weird results where POARequest exists but VeteranRepresentative does not.
      # exceptional_poa_codes = Set['862', 'BQX', '6B6', '9U7', '1EY']
      exceptional_poa_codes = Set[]
      exceptional_participant_ids = Set['13397031', '111']

      search_action =
        ClaimsApi::BGSClient::Definitions::
          ManageRepresentativeService::
          ReadPoaRequest::DEFINITION.name

      loop do
        poa_requests = search_poa_requests(page_number, page_size)
        poa_requests.each do |poa_request|
          participant_id = poa_request['vetPtcpntID']
          next if participant_id.blank?
          next if participant_id.in?(exceptional_participant_ids)

          participant_ids << participant_id

          next if poa_request['poaCode'].in?(exceptional_poa_codes)

          proc_id = poa_request['procID']
          comparisons[participant_id][proc_id][search_action] = poa_request
        end

        break if poa_requests.size < page_size

        page_number += 1
      end

      veteran_representative_action = 'readAllVeteranRepresentatives'

      poa_request_action =
        ClaimsApi::BGSClient::Definitions::
          ManageRepresentativeService::
          ReadPoaRequestByParticipantId::DEFINITION.name

      counter = participant_ids.size
      participant_ids.each do |participant_id|
        # puts counter # uncomment for some progress tracking
        counter -= 1

        veteran_representatives = get_veteran_representatives(participant_id)
        poa_requests = get_poa_requests(participant_id)

        veteran_representatives.each do |veteran_representative|
          next if veteran_representative['poaCode'].in?(exceptional_poa_codes)

          # These two are about visibility logic for POARequest due to statuses.
          next if veteran_representative['secondaryStatus'].to_s.strip.downcase == 'obsolete'
          next unless veteran_representative['vdcStatus'].to_s.strip.downcase == 'submitted'

          comparison =
            comparisons.dig(
              participant_id,
              veteran_representative['procId']
            )

          comparison[veteran_representative_action] =
            veteran_representative
        end

        poa_requests.each do |poa_request|
          next if poa_request['poaCode'].in?(exceptional_poa_codes)

          comparison =
            comparisons.dig(
              participant_id,
              poa_request['procID']
            )

          comparison[poa_request_action] =
            poa_request
        end
      end

      records = comparisons.values.flat_map(&:values)
      categories = records.group_by(&:keys)
      tally = categories.transform_values(&:size)

      expect(tally).to eq(
        %w[readPOARequest readAllVeteranRepresentatives readPOARequestByPtcpntId] => 52,
        # These are because `readPOARequestByPtcpntId` only returns the latest.
        %w[readPOARequest readAllVeteranRepresentatives] => 31,
        # This anomaly I don't understand. They seem like they may not be
        # produced in a production setting. The `exceptional_poa_codes`
        # condition targets these when uncommented.
        %w[readPOARequest readPOARequestByPtcpntId] => 5
      )

      summary =
        comparisons.values.filter_map do |participant|
          memo = {
            'readPOARequest' => [],
            'readAllVeteranRepresentatives' => [],
            'readPOARequestByPtcpntId' => []
          }

          participant.each_value do |comparison|
            comparison.each do |key, value|
              memo[key] <<
                case key
                when 'readAllVeteranRepresentatives'
                  value['submittedDate']
                else
                  value['dateRequestReceived']
                end
            end
          end

          next if memo['readPOARequest'].size == 1

          memo
        end

      expect(summary).to eq(
        [
          {
            'readPOARequest' => [
              '2013-02-11T09:06:50-06:00',
              '2014-07-16T09:54:31-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2013-02-11T09:06:50-06:00',
              '2014-07-16T09:54:31-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2014-07-16T09:54:31-05:00'
            ]
          },
          { # This is the only representative of the missing `readAllVeteranRepresentatives` anomalies above.
            'readPOARequest' => [
              '2013-08-29T14:09:33-05:00',
              '2015-10-19T09:04:34-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2013-08-29T14:09:33-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2015-10-19T09:04:34-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2015-03-25T17:12:26-05:00',
              '2015-04-03T17:00:53-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2015-03-25T17:12:26-05:00',
              '2015-04-03T17:00:53-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2015-04-03T17:00:53-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2015-08-18T21:44:30-05:00',
              '2017-05-16T11:16:37-05:00',
              '2017-07-10T09:59:12-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2015-08-18T21:44:30-05:00',
              '2017-05-16T11:16:37-05:00',
              '2017-07-10T09:59:12-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2017-07-10T09:59:12-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2016-12-06T13:12:43-06:00',
              '2017-04-26T16:26:36-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2016-12-06T13:12:43-06:00',
              '2017-04-26T16:26:36-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2017-04-26T16:26:36-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2017-07-10T15:14:30-05:00',
              '2017-10-18T13:59:29-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2017-07-10T15:14:30-05:00',
              '2017-10-18T13:59:29-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2017-10-18T13:59:29-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2017-10-18T13:35:46-05:00',
              '2024-04-05T12:08:02-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2017-10-18T13:35:46-05:00',
              '2024-04-05T12:08:02-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2024-04-05T12:08:02-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2018-02-09T07:46:42-06:00',
              '2018-05-09T15:10:47-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2018-02-09T07:46:42-06:00',
              '2018-05-09T15:10:47-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2018-05-09T15:10:47-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2018-10-04T10:36:26-05:00',
              '2018-10-04T12:55:44-05:00',
              '2018-11-08T10:18:10-06:00',
              '2018-11-16T10:11:22-06:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2018-10-04T10:36:26-05:00',
              '2018-10-04T12:55:44-05:00',
              '2018-11-08T10:18:10-06:00',
              '2018-11-16T10:11:22-06:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2018-11-16T10:11:22-06:00'
            ]
          },
          {
            'readPOARequest' => [
              '2019-02-05T10:34:33-06:00',
              '2020-04-24T13:51:15-05:00',
              '2022-04-12T16:05:26-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2019-02-05T10:34:33-06:00',
              '2020-04-24T13:51:15-05:00',
              '2022-04-12T16:05:26-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2022-04-12T16:05:26-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2020-02-25T13:56:42-06:00',
              '2020-04-30T07:56:44-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2020-02-25T13:56:42-06:00',
              '2020-04-30T07:56:44-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2020-04-30T07:56:44-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2021-10-15T08:36:33-05:00',
              '2023-05-16T11:06:07-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2021-10-15T08:36:33-05:00',
              '2023-05-16T11:06:07-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2023-05-16T11:06:07-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2023-03-30T08:41:51-05:00',
              '2023-05-24T10:04:31-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2023-03-30T08:41:51-05:00',
              '2023-05-24T10:04:31-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2023-05-24T10:04:31-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2023-08-23T12:16:37-05:00',
              '2024-05-10T09:30:23-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2023-08-23T12:16:37-05:00',
              '2024-05-10T09:30:23-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2024-05-10T09:30:23-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2023-09-07T13:46:48-05:00',
              '2024-05-30T14:36:09-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2023-09-07T13:46:48-05:00',
              '2024-05-30T14:36:09-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2024-05-30T14:36:09-05:00'
            ]
          },
          {
            'readPOARequest' => [
              '2024-03-01T09:13:08-06:00',
              '2024-03-08T07:56:37-06:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2024-03-01T09:13:08-06:00',
              '2024-03-08T07:56:37-06:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2024-03-08T07:56:37-06:00'
            ]
          },
          {
            'readPOARequest' => [
              '2024-04-04T13:08:05-05:00',
              '2024-04-16T15:21:38-05:00',
              '2024-04-18T13:01:27-05:00',
              '2024-04-18T13:57:50-05:00',
              '2024-04-19T14:20:45-05:00',
              '2024-04-22T10:31:30-05:00',
              '2024-04-23T12:55:08-05:00',
              '2024-05-22T14:25:07-05:00',
              '2024-05-23T07:42:50-05:00',
              '2024-05-23T08:40:27-05:00',
              '2024-05-29T15:20:45-05:00',
              '2024-05-30T08:51:01-05:00'
            ],
            'readAllVeteranRepresentatives' => [
              '2024-04-04T13:08:05-05:00',
              '2024-04-16T15:21:38-05:00',
              '2024-04-18T13:01:27-05:00',
              '2024-04-18T13:57:50-05:00',
              '2024-04-19T14:20:45-05:00',
              '2024-04-22T10:31:30-05:00',
              '2024-04-23T12:55:08-05:00',
              '2024-05-22T14:25:07-05:00',
              '2024-05-23T07:42:50-05:00',
              '2024-05-23T08:40:27-05:00',
              '2024-05-29T15:20:45-05:00',
              '2024-05-30T08:51:01-05:00'
            ],
            'readPOARequestByPtcpntId' => [
              '2024-05-30T08:51:01-05:00'
            ]
          }
        ]
      )
    end
  end

  def search_poa_requests(page_number, page_size) # rubocop:disable Metrics/MethodLength
    poa_codes = %w[
      002 003 004 005 006 007 008 009 00V 010 012 014 015 016 017 018 019 020
      021 022 023 025 027 028 030 031 032 033 034 035 036 037 038 039 040 041
      043 044 045 046 047 048 049 050 051 052 054 055 056 059 060 064 065 070
      071 073 074 075 077 078 079 080 081 082 083 084 085 086 087 088 090 091
      093 094 097 095 097 1EY 4R0 4R2 4R3 6B6 862 869 8FE 9U7 BQX E5L FYT HTC
      HW0 IP4 J3C JCV
    ]

    action =
      ClaimsApi::BGSClient::Definitions::
        ManageRepresentativeService::
        ReadPoaRequest::DEFINITION

    result =
      ClaimsApi::BGSClient.perform_request(action) do |xml, data_aliaz|
        xml[data_aliaz].POACodeList do
          poa_codes.each do |poa_code|
            xml.POACode(poa_code)
          end
        end

        xml[data_aliaz].SecondaryStatusList do
          xml.SecondaryStatus('New')
          xml.SecondaryStatus('Pending')
          xml.SecondaryStatus('Accepted')
          xml.SecondaryStatus('Declined')
        end

        xml[data_aliaz].POARequestParameter do
          xml.pageIndex(page_number)
          xml.pageSize(page_size)
        end
      end

    Array.wrap(result['poaRequestRespondReturnVOList'])
  end

  def get_poa_requests(participant_id)
    action =
      ClaimsApi::BGSClient::Definitions::
        ManageRepresentativeService::
        ReadPoaRequestByParticipantId::DEFINITION

    result =
      ClaimsApi::BGSClient.perform_request(action) do |xml|
        xml.PtcpntId(participant_id)
      end

    Array.wrap(result['poaRequestRespondReturnVOList'])
  end

  def get_veteran_representatives(participant_id)
    options = {}
    options[:participant_id] = participant_id
    result = ClaimsApi::VeteranRepresentativeService.new(
      external_uid: participant_id,
      external_key: participant_id
    ).read_all_veteran_representatives(options)

    Array.wrap(result)
  end
end
