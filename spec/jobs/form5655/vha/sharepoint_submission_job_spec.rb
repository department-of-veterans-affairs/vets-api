# frozen_string_literal: true

require 'rails_helper'

require 'debt_management_center/sharepoint/request'

RSpec.describe Form5655::VHA::SharepointSubmissionJob, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  describe '#perform' do
    let(:form_submission) { create(:form5655_submission) }

    before do
      response = Faraday::Response.new(status: 200, body:
        {
          message: 'Success'
        })

      allow_any_instance_of(DebtManagementCenter::Sharepoint::Request)
        .to receive(:set_sharepoint_access_token)
        .and_return('123abc')
      allow_any_instance_of(DebtManagementCenter::Sharepoint::Request).to receive(:upload).and_return(response)
    end

    it 'uploads to the SharePoint repository' do
      job = described_class.new
      expect_any_instance_of(DebtManagementCenter::Sharepoint::Request).to receive(:upload).with(
        form_contents: form_submission.form,
        form_submission:,
        station_id: form_submission.form['facilityNum']
      )
      job.perform(form_submission.id)
    end
  end
end
