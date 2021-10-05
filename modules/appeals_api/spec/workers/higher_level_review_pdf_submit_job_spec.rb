# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

RSpec.describe AppealsApi::HigherLevelReviewPdfSubmitJob, type: :job do
  include FixtureHelpers

  subject { described_class }

  before { Sidekiq::Worker.clear_all }

  let(:auth_headers) { fixture_to_s 'valid_200996_headers.json' }
  let(:higher_level_review) { create_higher_level_review }
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_doc) { fixture_to_s 'valid_200996.json' }

  it_behaves_like 'a monitored worker'

  it 'uploads a valid payload' do
    allow(CentralMail::Service).to receive(:new) { client_stub }
    allow(faraday_response).to receive(:status).and_return(200)
    allow(faraday_response).to receive(:body).and_return('')
    allow(faraday_response).to receive(:success?).and_return(true)
    capture_body = nil
    expect(client_stub).to receive(:upload) { |arg|
      capture_body = arg
      faraday_response
    }
    described_class.new.perform(higher_level_review.id)
    expect(capture_body).to be_a(Hash)
    expect(capture_body).to have_key('metadata')
    expect(capture_body).to have_key('document')
    metadata = JSON.parse(capture_body['metadata'])
    expect(metadata['uuid']).to eq(higher_level_review.id)
    updated = AppealsApi::HigherLevelReview.find(higher_level_review.id)
    expect(updated.status).to eq('submitted')
  end

  it 'sets error status for upstream server error' do
    allow(CentralMail::Service).to receive(:new) { client_stub }
    allow(faraday_response).to receive(:status).and_return(422)
    allow(faraday_response).to receive(:body).and_return('')
    allow(faraday_response).to receive(:success?).and_return(false)
    capture_body = nil
    expect(client_stub).to receive(:upload) { |arg|
      capture_body = arg
      faraday_response
    }

    expect { described_class.new.perform(higher_level_review.id) }.to raise_error(AppealsApi::UploadError)
    expect(capture_body).to be_a(Hash)
    expect(capture_body).to have_key('metadata')
    expect(capture_body).to have_key('document')
    metadata = JSON.parse(capture_body['metadata'])
    expect(metadata['uuid']).to eq(higher_level_review.id)
    updated = AppealsApi::HigherLevelReview.find(higher_level_review.id)
    expect(updated.status).to eq('error')
    expect(updated.code).to eq('DOC104')
  end

  context 'with a downstream error' do
    before do
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(500)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(false)
    end

    it 'puts the HLR into an error state' do
      expect(client_stub).to receive(:upload) { |_arg| faraday_response }
      messager_instance = instance_double(AppealsApi::Slack::Messager)
      allow(AppealsApi::Slack::Messager).to receive(:new).and_return(messager_instance)
      allow(messager_instance).to receive(:notify!).and_return(true)
      described_class.new.perform(higher_level_review.id)
      expect(higher_level_review.reload.status).to eq('error')
      expect(higher_level_review.code).to eq('DOC201')
    end

    it 'sends a retry notification' do
      expect(client_stub).to receive(:upload) { |_arg| faraday_response }
      messager_instance = instance_double(AppealsApi::Slack::Messager)
      allow(AppealsApi::Slack::Messager).to receive(:new).and_return(messager_instance)
      allow(messager_instance).to receive(:notify!).and_return(true)
      described_class.new.perform(higher_level_review.id)

      expect(messager_instance).to have_received(:notify!)
    end
  end

  context 'an error throws' do
    it 'updates the HLR status to reflect the error' do
      submit_job_worker = described_class.new
      allow(submit_job_worker).to receive(:upload_to_central_mail).and_raise(RuntimeError, 'runtime error!')

      expect do
        submit_job_worker.perform(higher_level_review.id)
      end.to raise_error(RuntimeError, 'runtime error!')

      higher_level_review.reload
      expect(higher_level_review.status).to eq('error')
      expect(higher_level_review.code).to eq('RuntimeError')
    end
  end

  private

  def create_higher_level_review
    higher_level_review = create(:higher_level_review)
    higher_level_review.auth_headers = JSON.parse(auth_headers)
    higher_level_review.save
    higher_level_review
  end
end
