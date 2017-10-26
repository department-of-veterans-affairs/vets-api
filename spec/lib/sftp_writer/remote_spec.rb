# frozen_string_literal: true

RSpec.describe SFTPWriter::Remote do
  subject { described_class }

  describe '#close' do
    it 'should return if sftp has not started' do
      expect(described_class.new({}, logger: {}).close).to eq(nil)
    end
  end
end
