# frozen_string_literal: true
require 'rails_helper'

RSpec.describe HCA::ServiceJob, type: :job do
  let(:user) { create(:user) }
  let(:health_care_application) { create(:health_care_application) }
  let(:form) { { foo: true } }
  let(:result) do
    {
      formSubmissionId: 123,
      timestamp: '2017-08-03 22:02:18 -0400'
    }
  end
  let(:hca_service) do
    double
  end

  describe '#perform' do
    before do
      # this line is needed to make stub in next line work because the found user is not == to another instance of itself
      expect(User).to receive(:find).with(user.uuid).once.and_return(user)
      expect(HCA::Service).to receive(:new).with(user).once.and_return(hca_service)
      expect(hca_service).to receive(:submit_form).with(form).once.and_return(result)
      expect(Rails.logger).to receive(:info).with("SubmissionID=#{result[:formSubmissionId]}")
    end

    subject do
      described_class.new.perform(user.uuid, form, health_care_application.id)
    end

    it 'should call the service and save the results' do
      subject
      health_care_application.reload

      expect(health_care_application.success?).to eq(true)
      expect(health_care_application.form_submission_id).to eq(result[:formSubmissionId])
      expect(health_care_application.timestamp).to eq(result[:timestamp])
    end
  end
end
