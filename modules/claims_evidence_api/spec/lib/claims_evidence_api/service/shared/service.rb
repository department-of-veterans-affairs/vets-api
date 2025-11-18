# frozen_string_literal: true

require 'claims_evidence_api/monitor'

shared_examples_for 'a ClaimsEvidenceApi::Service class' do
  let(:monitor) { ClaimsEvidenceApi::Monitor::Service.new }

  before do
    allow(ClaimsEvidenceApi::Monitor::Service).to receive(:new).and_return monitor
  end

  describe '#perform' do
    let(:service) { subject.class.new } # instance of the invoking class
    let(:endpoint) { service.send(:endpoint) || 'test' }

    it 'tracks the request' do
      # 'Authorization' is added to each request
      args = [:get, 'test/path', { param: 1 }, { header: 'test', 'Authorization' => /Bearer/ }, { option: 'test' }]
      response = build(:claims_evidence_service_files_response, :success)

      # 'request' is a method within the `super` chain
      expect(service).to receive(:request).with(*args).and_return response
      expect(monitor).to receive(:track_api_request).with(:get, endpoint, 200, 'OK', call_location: anything)

      service.perform(*args)
    end

    it 'tracks and raise exception on error response' do
      # 'Authorization' is added to each request
      args = [:get, 'test/path', { param: 1 }, { header: 'test', 'Authorization' => /Bearer/ }, { option: 'test' }]
      error = build(:claims_evidence_service_files_error, :error)

      # 'request' is a method within the `super` chain
      expect(service).to receive(:request).with(*args).and_raise error
      expect(monitor).to receive(:track_api_request).with(:get, endpoint, 503, 'VEFSERR40009',
                                                          call_location: anything)

      expect { service.perform(*args) }.to raise_error error
    end
  end

  context 'sets and retrieves folder_identifier' do
    it 'accepts separate arguments' do
      subject = described_class.new

      args = %w[VETERAN FILENUMBER 987267855]
      folder_identifier = subject.folder_identifier_set(*args)
      expect(folder_identifier).to eq subject.folder_identifier
      expect(folder_identifier).to eq args.join(':')
    end

    it 'directly assigns the value' do
      subject = described_class.new

      fid = 'VETERAN:FILENUMBER:987267855'
      subject.folder_identifier = fid
      expect(fid).to eq subject.folder_identifier
    end
  end
end
