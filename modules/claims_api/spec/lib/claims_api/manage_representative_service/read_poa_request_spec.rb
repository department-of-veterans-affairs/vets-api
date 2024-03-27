# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/manage_representative_service'

describe ClaimsApi::ManageRepresentativeService do
  subject do
    service = described_class.new(external_uid: 'xUid', external_key: 'xKey')
    service.read_poa_request(**arguments)
  end

  describe '#read_poa_request' do
    describe 'with no arguments' do
      let(:arguments) { {} }

      it 'raises ::Common::Exceptions::ServiceError' do
        use_cassette('manage_representative_service', 'read_poa_request') do
          expect { subject }.to(
            raise_error(::Common::Exceptions::ServiceError)
          )
        end
      end
    end

    describe 'with no statuses argument' do
      let(:arguments) do
        {
          poa_codes: ['1'],
        }
      end

      it 'raises ::Common::Exceptions::ServiceError' do
        use_cassette('manage_representative_service', 'read_poa_request') do
          expect { subject }.to(
            raise_error(::Common::Exceptions::ServiceError)
          )
        end
      end
    end

    describe 'with invalid status in statuses argument' do
      let(:arguments) do
        {
          poa_codes: ['1'],
          statuses: ['invalid', 'new'],
        }
      end

      it 'raises ::Common::Exceptions::ServiceError' do
        use_cassette('manage_representative_service', 'read_poa_request') do
          expect { subject }.to(
            raise_error(::Common::Exceptions::ServiceError)
          )
        end
      end
    end

    describe 'with no poa_codes argument' do
      let(:arguments) do
        {
          statuses: ['new'],
        }
      end

      it 'raises ::Common::Exceptions::ServiceError' do
        use_cassette('manage_representative_service', 'read_poa_request') do
          expect { subject }.to(
            raise_error(::Common::Exceptions::ServiceError)
          )
        end
      end
    end

    describe 'with nonexistent poa_code argument' do
      let(:arguments) do
        {
          poa_codes: ['1'],
          statuses: ['new'],
        }
      end

      it 'raises ::Common::Exceptions::ServiceError' do
        use_cassette('manage_representative_service', 'read_poa_request') do
          expect { subject }.to(
            raise_error(::Common::Exceptions::ServiceError)
          )
        end
      end
    end

    describe 'with existent poa_code argument' do
      let(:arguments) do
        {
          poa_codes: ['091'],
          statuses: ['new'],
        }
      end

      it 'returns poa requests' do
        use_cassette('manage_representative_service', 'read_poa_request') do
          expect(subject).to eq({
            poa_request_respond_return_vo_list: {
              vso_user_email: nil,
              vso_user_first_name: "VDC USER",
              vso_user_last_name: nil,
              change_address_auth: "Y",
              claimant_city: "SEASIDE",
              claimant_country: "USA",
              claimant_military_po: nil,
              claimant_military_postal_code: nil,
              claimant_state: "MT",
              claimant_zip: "95102",
              date_request_actioned: "2015-08-05T11:33:20-05:00",
              date_request_received: "2015-08-05T11:33:20-05:00",
              declined_reason: nil,
              health_info_auth: "N",
              poa_code: "091",
              proc_id: "52095",
              secondary_status: "New",
              vet_first_name: "Wallace",
              vet_last_name: "Webb",
              vet_middle_name: "R",
              vet_ptcpnt_id: "600043200"
            },
            total_nbr_of_records: "1"
          })
        end
      end
    end
  end

  # TODO-BEGIN: Move to spec helpers.
  def use_cassette(service, operation, &)
    scenario = RSpec.current_example.full_description
    file_path = ['bgs', service, operation, scenario].join('/')
    options = {match_requests_on: [:method, :uri, :xml_body]}
    VCR.use_cassette(file_path, options, &)
  end

  VCR.configure do |config|
    config.register_request_matcher :xml_body do |req_a, req_b|
      xml_a = Nokogiri::XML(req_a.body, &:noblanks).canonicalize
      xml_b = Nokogiri::XML(req_b.body, &:noblanks).canonicalize
      xml_a == xml_b
    end
  end
  # TODO-END:
end
