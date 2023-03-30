# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::GIBillFeedbacksController, type: :controller do
  let(:form) { build(:gi_bill_feedback).form }
  let(:user) { create(:user) }

  it_behaves_like 'a controller that deletes an InProgressForm',
                  'gi_bill_feedback', 'gi_bill_feedback', GIBillFeedback::FORM_ID

  def parsed_body
    JSON.parse(response.body)
  end

  describe '#create' do
    def send_create
      post(:create, params: { gi_bill_feedback: { form: } })
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
        expect(Raven).to receive(:tags_context).with(validation: 'gibft').at_least(:once)
        post(:create, params: { gi_bill_feedback: { form: { foo: 1 }.to_json } })

        expect(response.status).to eq(422)
        expect(parsed_body['errors'][0]['title'].include?('contains additional properties')).to eq(true)
      end
    end
  end

  describe '#show' do
    it 'finds a gi bill feedback submission by guid' do
      gi_bill_feedback = create(:gi_bill_feedback)
      get(:show, params: { id: gi_bill_feedback.guid })
      expect(parsed_body['data']['id']).to eq(gi_bill_feedback.id)
      expect(parsed_body['data']['attributes'].keys).to eq(%w[guid state parsed_response])
    end
  end
end
