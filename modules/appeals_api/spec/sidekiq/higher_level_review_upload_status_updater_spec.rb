# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::HigherLevelReviewUploadStatusUpdater, type: :job do
  let(:client_stub) { instance_double(CentralMail::Service) }
  let(:upload) { create(:higher_level_review_v2, status: 'submitting') }
  let(:faraday_response) { instance_double(Faraday::Response) }
  let(:in_process_element) do
    [{ uuid: 'ignored',
       status: 'In Process',
       errorMessage: '',
       lastUpdated: '2018-04-25 00:02:39' },
     { uuid: 'ignored',
       status: 'In Process',
       errorMessage: '',
       lastUpdated: '2018-04-25 00:02:39' }]
  end

  after do
    client_stub { nil }
    faraday_response { nil }
  end

  it_behaves_like 'a monitored worker'

  describe '#perform' do
    it 'updates the status of a HigherLevelReview' do
      expect(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)
      in_process_element[0]['uuid'] = upload.id
      expect(faraday_response).to receive(:body).at_least(:once).and_return([in_process_element].to_json)

      AppealsApi::HigherLevelReviewUploadStatusUpdater.new.perform([upload])
      upload.reload
      expect(upload.status).to eq('processing')
    end

    it 'logs to rails & notifies slack of individual bad records without affecting good records' do
      bad_upload = create(:higher_level_review_v2, status: 'submitting')
      # Intentionally break decrypting
      bad_upload.update_column :form_data_ciphertext, ':(' # rubocop:disable Rails/SkipsModelValidations

      expect(CentralMail::Service).to receive(:new) { client_stub }
      expect(client_stub).to receive(:status).and_return(faraday_response)
      expect(faraday_response).to receive(:success?).and_return(true)

      in_process_element[0]['uuid'] = bad_upload.id
      in_process_element[1]['uuid'] = upload.id
      expect(faraday_response).to receive(:body).at_least(:once).and_return(in_process_element.to_json)

      expect_any_instance_of(AppealsApi::Slack::Messager).to receive(:notify!).once
      expect(Rails.logger).to receive(:error).twice

      AppealsApi::HigherLevelReviewUploadStatusUpdater.new.perform([bad_upload, upload])
      upload.reload
      bad_upload.reload
      expect(upload.status).to eq('processing')
      expect(bad_upload.status).to eq('submitting')
    end
  end
end
