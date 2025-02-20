# frozen_string_literal: true

require 'rails_helper'
require 'sftp_writer/remote'

RSpec.describe SFTPWriter::Remote do
  describe '#close' do
    it 'returns if sftp has not started' do
      expect(described_class.new({}, logger: {}).close).to be_nil
    end
  end

  describe '#sanitize' do
    it 'returns a filename without colons' do
      result = described_class.new({}, logger: {}).send(:sanitize, 'test:foo:bar.pdf')
      expect(result).to eq('test_foo_bar.pdf')
    end
  end
end
