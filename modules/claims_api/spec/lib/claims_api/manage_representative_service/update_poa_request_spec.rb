# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/manage_representative_service'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_spec_helpers.rb')

metadata = {
  bgs: {
    service: 'manage_representative_service',
    action: 'update_poa_request'
  }
}

describe ClaimsApi::ManageRepresentativeService, metadata do
  describe '#update_poa_request' do
    subject do
      service = described_class.new(**header_params)
      service.update_poa_request(**params)
    end

    describe 'on the happy path' do
      let(:header_params) do
        {
          external_uid: 'abcdefg',
          external_key: 'abcdefg'
        }
      end

      let(:params) do
        representative =
          create(
            :representative,
            {
              poa_codes: ['A1Q'],
              first_name: 'abraham',
              last_name: 'lincoln'
            }
          )

        {
          proc_id: '8675309',
          representative:
        }
      end

      it 'responds with attributes', run_at: '2024-03-27T13:05:01Z' do
        use_bgs_cassette('happy_path') do
          expect(subject).to eq(
            {
              'VSOUserEmail' => nil,
              'VSOUserFirstName' => params[:representative].first_name,
              'VSOUserLastName' => params[:representative].last_name,
              'declinedReason' => nil,
              'procId' => params[:proc_id],
              'secondaryStatus' => 'OBS',
              'dateRequestActioned' =>
                # Formatting this to show the difference between the date returned
                # in response and the date sent in request.
                Time.current.in_time_zone('America/Chicago').iso8601
            }
          )
        end
      end
    end
  end
end
