# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::CloudTransfer do
  describe '::download' do
    let(:filename) { instance_double(String) }
    let(:file) { instance_double(Pathname) }
    let(:client) { instance_double(Aws::S3::Client) }

    it 'downloads the dataset from the cloud and yields the path to caller' do
      expect(described_class).to receive(:tmp_path).with(filename).and_return(file)
      expect(described_class).to receive(:s3_client).and_return(client)
      expect(client).to receive(:get_object)
      expect(file).to receive(:delete)

      described_class.download(filename) do |received_file|
        expect(received_file).to eq(file)
      end
    end
  end
end
