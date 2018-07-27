# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::GIBillFeedbacksController, type: :controller do
  it_should_behave_like 'a controller that deletes an InProgressForm', 'gi_bill_feedback', 'gi_bill_feedback', GIBillFeedback::FORM_ID

  def parsed_body
    JSON.parse(response.body)
  end

  let(:user) { create(:user) }
  let(:form) { build(:gi_bill_feedback).form }

  describe '#create' do
    def send_create
      post(:create, gi_bill_feedback: { form: form })
    end

    context 'with a valid form' do
      it 'creates a gi bill feedback submission' do
        send_create
        expect(GIBillFeedback.find(parsed_body['data']['attributes']['guid']).present?).to eq(true)
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
