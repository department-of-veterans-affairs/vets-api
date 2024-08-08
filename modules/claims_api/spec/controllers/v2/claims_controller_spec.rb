# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

RSpec.describe ClaimsApi::V2::Veterans::ClaimsController, type: :controller do
  let(:target_veteran) do
    OpenStruct.new(
      icn: '1012832025V743496',
      first_name: 'Wesley',
      last_name: 'Ford',
      loa: { current: 3, highest: 3 },
      edipi: '1007697216',
      ssn: '796043735',
      participant_id: '600061742',
      mpi: OpenStruct.new(
        icn: '1012832025V743496',
        profile: OpenStruct.new(ssn: '796043735')
      )
    )
  end

  describe 'GET #index' do
    let(:veteran_icn) { target_veteran.icn }

    context 'when there are nil bgs and lighthouse claims' do
      before do
        allow(controller).to receive_messages(target_veteran:, find_bgs_claims!: nil)
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:where).with(veteran_icn:).and_return(nil)

        controller.send(:set_bgs_claims)
        controller.send(:set_lighthouse_claims)
      end

      # testing this line in the controller: render json: [] && return unless @bgs_claims || @lighthouse_claims
      # when unless comes back as false
      # && takes a higher precendence then the render method
      # so, [] && return is evaluated first
      # [] is an array object, so that is truthy
      # so, && returns the right side of the operation, which is return
      # which stops everything else and just triggers the render method without the additional information
      # specifically, json: []
      # resulting in "" being rendered
      it 'returns an empty response' do
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq('')
      end
    end
  end
end
