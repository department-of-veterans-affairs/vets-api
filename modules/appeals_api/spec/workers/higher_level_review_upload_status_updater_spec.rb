# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::HigherLevelReviewUploadStatusUpdater, type: :job do
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:upload1) { create(:higher_level_review, :status_received) }
  let(:upload2) { create(:higher_level_review, :status_received) }
  let(:faraday_response) { instance_double('Faraday::Response') }

  describe '#perform' do
    it 'updates the status of a HigherLevelReview' do
      expect(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      returned_status = {
        "uuid": upload1.id,
        "status": 'In Process',
        "errorMessage": '',
        "lastUpdated": '2018-04-25 00:02:39'
      }
      expect(faraday_response).to receive(:body).at_least(:once).and_return([[returned_status]].to_json)

      with_settings(Settings.modules_appeals_api, higher_level_review_updater_enabled: true) do
        AppealsApi::HigherLevelReviewUploadStatusUpdater.new.perform([upload1])
        upload1.reload
        expect(upload1.status).to eq('processing')
      end
    end

    it 'empty response is OK' do
      expect(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      expect(faraday_response).to receive(:body).at_least(:once).and_return([[]].to_json)

      with_settings(Settings.modules_appeals_api, higher_level_review_updater_enabled: true) do
        AppealsApi::HigherLevelReviewUploadStatusUpdater.new.perform([upload2])
        upload2.reload
        expect(upload2.status).to eq('received')
      end
    end
  end
end
