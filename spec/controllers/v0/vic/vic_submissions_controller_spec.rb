# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::VIC::VICSubmissionsController, type: :controller do
  let(:form) { build(:vic_submission).form }
  let(:user) { create(:user) }
  it_should_behave_like 'a controller that deletes an InProgressForm', 'vic_submission', 'vic_submission', 'VIC'

  describe '#create' do
    def send_create
      post(:create, params: { vic_submission: { form: form } })
    end

    context 'with a valid form' do
      context 'without a user' do
        it 'creates a vic submission' do
          send_create
          expect(JSON.parse(response.body)['data']['attributes']['guid'])
            .to eq(VIC::VICSubmission.last.guid)
        end
      end

      context 'with a user' do
        before do
          sign_in_as(user)
          expect(controller).to receive(:clear_saved_form).with('VIC')
        end

        it 'creates a vic submission with a user' do
          expect_any_instance_of(VIC::VICSubmission).to receive(:user=)
          send_create
          expect(response.ok?).to eq(true)
        end

        context 'with an anonymous flagged submission' do
          let(:form) do
            form = build(:vic_submission).send(:parsed_form)
            form['processAsAnonymous'] = true
            form.to_json
          end

          it 'should not associate the vic_submission with a user' do
            expect_any_instance_of(VIC::VICSubmission).not_to receive(:user=)
            send_create
            expect(response.ok?).to eq(true)
          end
        end
      end
    end

    context 'with an invalid form' do
      it 'has an error in the response' do
        allow(Raven).to receive(:tags_context)
        expect(Raven).to receive(:tags_context).with(validation: 'vic').at_least(:once)
        post(:create, params: { vic_submission: { form: { foo: 1 }.to_json } })

        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors'][0]['title'])
          .to include('contains additional properties')
      end
    end
  end

  describe '#show' do
    it 'should find a vic submission by guid' do
      vic_submission = create(:vic_submission)
      get(:show, params: { id: vic_submission.guid })
      expect(JSON.parse(response.body)['data']['id'].to_i)
        .to eq(vic_submission.id)
      expect(JSON.parse(response.body)['data']['attributes'].keys)
        .to eq(%w[guid state response])
    end
  end
end
