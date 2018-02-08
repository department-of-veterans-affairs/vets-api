# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VIC::VICSubmissionsController, type: :controller do
  def parsed_body
    JSON.parse(response.body)
  end

  describe '#create' do
    context 'with a valid form' do
      it 'creates a vic submission' do
        post(:create, vic_submission: { form: build(:vic_submission).form })
        expect(parsed_body['data']['attributes']['guid']).to eq(VIC::VICSubmission.last.guid)
      end
    end

    context 'with an invalid form' do
      it 'has an error in the response' do
        post(:create, vic_submission: { form: { foo: 1 }.to_json })

        expect(response.status).to eq(422)
        expect(parsed_body['errors'][0]['title'].include?('contains additional properties')).to eq(true)
      end
    end
  end

  describe '#show' do
    it 'should find a vic submission by guid' do
      vic_submission = create(:vic_submission)
      get(:show, id: vic_submission.guid)
      expect(parsed_body['data']['id'].to_i).to eq(vic_submission.id)
      expect(parsed_body['data']['attributes'].keys).to eq(%w[guid state response])
    end
  end
end
