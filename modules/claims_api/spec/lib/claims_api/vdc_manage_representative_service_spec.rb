# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vdc_manage_representative_service'

describe ClaimsApi::VdcManageRepresentativeService do
  subject { described_class.new external_uid: 'abcdefg', external_key: 'abcdefg' }

  describe 'update_poa' do
    let(:identity) { FactoryBot.create(:user_identity) }

    it 'responds with attributes' do
      VCR.use_cassette('bgs/vdc_manage_representative_service/update_poa') do
        rep = FactoryBot.create(
          :representative,
          poa_codes: ['A1Q'],
          first_name: identity.first_name,
          last_name: identity.last_name
        )
        # Formatting this to show the difference between the date returned in response and the date sent in request
        date = Time.parse('2024-03-27T13:05:01Z').getlocal('-05:00').strftime('%Y-%m-%dT%H:%M:%S%:z')
        proc_id = '8675309'

        response = subject.update_poa(rep, proc_id)

        expect(response[:poa_request_update]).to include(
          {
            vso_user_email: nil,
            vso_user_first_name: rep.first_name,
            vso_user_last_name: rep.last_name,
            date_request_actioned: date,
            declined_reason: nil,
            proc_id:,
            secondary_status: 'OBS'
          }
        )
      end
    end
  end
end
