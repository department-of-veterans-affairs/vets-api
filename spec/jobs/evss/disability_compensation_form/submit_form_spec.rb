# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm, type: :job do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:form_json) { { data: "I'm a form" }.to_json }

  describe '.start' do
    it 'queues up the submit job and starts the workflow' do
      expect do
        EVSS::DisabilityCompensationForm::SubmitForm.start(user, form_json)
      end.to change(EVSS::DisabilityCompensationForm::SubmitForm.jobs, :size).by(1)
    end
  end

  describe '#perform' do
    let(:response) { instance_double('EVSS::DisabilityCompensationForm::FormSubmitResponse') }

    before(:each) do
      allow_any_instance_of(EVSS::DisabilityCompensationForm::Service)
        .to receive(:submit_form).with(form_json).and_return(response)
    end

    context 'when the form submission returns a claim_id' do
      before { allow(response).to receive(:claim_id).and_return(600_130_094) }

      it 'creates a disability_compensation_submission record' do
        expect { described_class.new.perform(user, form_json) }
          .to change(DisabilityCompensationSubmission, :count).by(1)
      end
    end

    context 'with a missing claim_id' do
      before { allow(response).to receive(:claim_id).and_return(nil) }

      it 'raises an argument error (to trigger job retry)' do
        expect { described_class.new.perform(user, form_json) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#on_success' do
    it 'calls submit uploads start' do
      expect(EVSS::DisabilityCompensationForm::SubmitUploads).to receive(:start).once.with(user.uuid)
      EVSS::DisabilityCompensationForm::SubmitForm.new.on_success({}, 'uuid' => user.uuid)
    end
  end
end
