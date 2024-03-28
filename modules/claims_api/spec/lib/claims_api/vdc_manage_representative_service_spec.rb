# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vdc_manage_representative_service'

describe ClaimsApi::VdcManageRepresentativeService do
  subject { described_class.new external_uid: 'abcdefg', external_key: 'abcdefg' }

  describe 'update_poa' do
    let(:options) { {} }

    it 'responds with attributes' do
      VCR.use_cassette('bgs/vdc_manage_representative_service/update_poa') do
        # Formatting this to show the difference between the date returned in response and the date sent in request
        date = Time.parse('2024-03-27T13:05:01Z').getlocal('-05:00').strftime('%Y-%m-%dT%H:%M:%S%:z')

        response = subject.update_poa
        expect(response[:poa_request_update]).to include(
          {
            vso_user_email: nil,
            vso_user_first_name: 'Test',
            vso_user_last_name: 'User',
            date_request_actioned: date,
            declined_reason: nil,
            proc_id: '8675309',
            secondary_status: 'OBS'
          }
        )
      end
    end
  end
end
