# frozen_string_literal: true

shared_examples_for 'a ClaimsEvidenceApi::Service class' do
  context 'sets and retrieves x_folder_uri' do
    it 'accepts separate arguments' do
      subject = described_class.new

      args = ['VETERAN', 'FILENUMBER', '987267855']
      x_folder_uri = subject.x_folder_uri_set(*args)
      expect(x_folder_uri).to eq subject.x_folder_uri
      expect(x_folder_uri).to eq args.join(':')
    end

    it 'directly assigns the value' do
      subject = described_class.new

      fid = 'VETERAN:FILENUMBER:987267855'
      x_folder_uri = subject.x_folder_uri = fid
      expect(fid).to eq subject.x_folder_uri
    end
  end
end
