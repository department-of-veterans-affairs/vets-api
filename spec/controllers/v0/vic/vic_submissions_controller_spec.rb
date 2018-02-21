# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::VIC::VICSubmissionsController, type: :controller do
  def parsed_body
    JSON.parse(response.body)
  end

  let(:user) { create(:user) }

  describe '#create' do
    def send_create
      post(:create, vic_submission: { form: build(:vic_submission).form })
    end

    context 'with a valid form' do
      context 'without a user' do
        it 'creates a vic submission' do
          send_create
          expect(parsed_body['data']['attributes']['guid']).to eq(VIC::VICSubmission.last.guid)
        end
      end

      context 'with a user' do
        it 'creates a vic submission with a user' do
          expect(controller).to receive(:authenticate_token)
          allow(controller).to receive(:current_user).and_return(user)
          expect_any_instance_of(VIC::VICSubmission).to receive(:user_uuid=).with(user.uuid)
          expect(controller).to receive(:clear_saved_form).with('VIC')
          send_create
          expect(response.ok?).to eq(true)
        end
      end
    end

    context 'with an invalid form' do
      it 'has an error in the response' do
        allow(Raven).to receive(:tags_context)
        expect(Raven).to receive(:tags_context).with(validation: 'vic').at_least(:once)
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
