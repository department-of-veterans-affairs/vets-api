# frozen_string_literal: true

require 'rails_helper'
require 'sftp_writer/factory'

RSpec.describe SFTPWriter::Factory, type: :model, form: :education_benefits do
  subject { described_class }

  it 'raises an error if in production but lacking auth keys' do
    expect(Rails.env).to receive('development?').once.and_return(false)

    with_settings(Settings.edu.sftp, host: 'localhost', pass: nil) do
      expect { subject.get_writer(Settings.edu.sftp) }.to raise_error(Exception, /SFTP cert not present/)
    end
  end

  it 'writes locally for development mode' do
    expect(Rails.env).to receive('development?').once.and_return(true)
    expect(subject.get_writer(Settings.edu.sftp)).to be(SFTPWriter::Local)
  end

  it 'writes to production when possible' do
    expect(Rails.env).to receive('development?').once.and_return(false)
    # any readable file will work for this spec
    key_path = ::Rails.root.join(*'/spec/fixtures/files/idme_cert.crt'.split('/')).to_s
    with_settings(Settings.edu.sftp, host: 'localhost', key_path:) do
      expect(subject.get_writer(Settings.edu.sftp)).to be(SFTPWriter::Remote)
    end
  end
end
