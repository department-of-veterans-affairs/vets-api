# frozen_string_literal: true

require 'claims_evidence_api/monitor'

shared_examples_for 'a ClaimsEvidenceApi::Service class' do
  let(:monitor) { ClaimsEvidenceApi::Monitor::Service.new }

  before do
    allow(ClaimsEvidenceApi::Monitor::Service).to receive(:new).and_return monitor
  end

  describe '#perform' do
    it 'tracks the request' do
      args = [:get, 'test/path', {param: 1}, {header: 'test'}, {option: 'test'}]
      response = build(:claims_evidence_service_files_response, :success)

       # 'request' is a method within the `super` chain
      expect(subject).to receive(:request).with(*args).and_return response
      expect(monitor).to receive(:track_api_request).with(:get, 'test/path', 200, 'OK', call_location: anything)

      subject.perform(*args)
    end

    it 'tracks and raise exception on error response' do
      args = [:get, 'test/path', {param: 1}, {header: 'test'}, {option: 'test'}]
      error = build(:claims_evidence_service_files_error, :error)

      # 'request' is a method within the `super` chain
      expect(subject).to receive(:request).with(*args).and_raise error
      expect(monitor).to receive(:track_api_request).with(:get, 'test/path', 503, 'VEFSERR40009', call_location: anything)

      expect { subject.perform(*args) }.to raise_error error
    end
  end

  context 'sets and retrieves x_folder_uri' do
    it 'accepts separate arguments' do
      subject = described_class.new

      args = %w[VETERAN FILENUMBER 987267855]
      x_folder_uri = subject.x_folder_uri_set(*args)
      expect(x_folder_uri).to eq subject.x_folder_uri
      expect(x_folder_uri).to eq args.join(':')
    end

    it 'directly assigns the value' do
      subject = described_class.new

      fid = 'VETERAN:FILENUMBER:987267855'
      subject.x_folder_uri = fid
      expect(fid).to eq subject.x_folder_uri
    end
  end
end
