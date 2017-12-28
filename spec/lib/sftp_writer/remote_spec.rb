# frozen_string_literal: true

RSpec.describe SFTPWriter::Remote do
  describe '#close' do
    it 'should return if sftp has not started' do
      expect(described_class.new({}, logger: {}).close).to eq(nil)
    end
  end

  describe '#sanitize' do
    it 'should return a filename without colons' do
      result = described_class.new({}, logger: {}).send(:sanitize, 'test:foo:bar.pdf')
      expect(result).to eq('test_foo_bar.pdf')
    end
  end
end
