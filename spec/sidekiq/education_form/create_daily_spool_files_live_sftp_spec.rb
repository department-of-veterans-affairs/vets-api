# frozen_string_literal: true

require 'rails_helper'

# Skip the test if ENV['RUN_SFTP_TEST'] is not set to 'true'. This will blow up the pipeline
# and fail if you try to run it in Github.
# To run it, copy and paste the below onto the command line
# RUN_SFTP_TEST=true rspec spec/sidekiq/education_form/create_daily_spool_files_live_sftp_spec.rb
if ENV['RUN_SFTP_TEST'] == 'true'
  # To set this up, you need to have another machine in your network that you can ssh into.
  # To install the ssh server on that machine (linux) do: sudo apt install openssh-server
  # You will also need to copy your id_rsa.pub file to that machine. Typically thats located
  # at ~/.ssh/id_rsa.pub. Use ssh-copy-id to copy the file over and make the ssh key login work.
  # Then configure the settings below (use settings.local.yml) to point to that machine.
  # I encountered a situation where the remote machine was unreachable. Bouncing this VM fixed it.
  # Also ensure that the ssh service is running on the remote machine. systemctl status ssh
  # The remote machine should be configured with a bridged adapter if you are using virtualbox.
  # Set the host ip, key_path, user, port, and relative_307_path in your settings.local.yml
  RSpec.describe EducationForm::CreateDailySpoolFiles, form: :education_benefits, type: :model do
    subject { described_class.new }

    # rubocop:disable Naming/VariableNumber
    let!(:application_1606) do
      create(:va1990).education_benefits_claim
    end
    # rubocop:enable Naming/VariableNumber

    let(:line_break) { EducationForm::CreateDailySpoolFiles::WINDOWS_NOTEPAD_LINEBREAK }

    before do
      local_settings_path = Rails.root.join('config', 'settings.local.yml')

      if File.exist?(local_settings_path)
        local_settings = YAML.load_file(local_settings_path) || {}
        Settings.add_source!(local_settings)
        Settings.reload!
      end

      allow(Flipper).to receive(:enabled?).and_call_original
    end

    after(:all) do
      FileUtils.rm_rf('tmp/spool_files')
    end

    context 'write_files', run_at: '2016-09-17 03:00:00 EDT' do
      let(:filename) { '307_09172016_070000_vetsgov.spl' }
      let!(:second_record) { create(:va1995) }

      # If you're remote is using /home/user/Downloads, mkdir_save blows up and the test fails.
      # Override this behavior. It does not like trying to make /home/user
      before do
        allow_any_instance_of(SFTPWriter::Remote).to receive(:mkdir_safe).and_return(true)
      end

      context 'in the production env' do
        it 'counts the number of bytes written in a live sftp' do
          allow(Rails.env).to receive(:production?).and_return(true)
          allow(Settings).to receive(:hostname).and_return('api.va.gov')

          instance = described_class.new
          allow(instance).to receive(:log_to_slack)

          with_settings(Settings.edu.sftp, Settings.edu.sftp.to_h) do
            log_message = 'Uploaded 4619 bytes to region: eastern'
            instance.perform
            expect(instance).to have_received(:log_to_slack).with(include(log_message))
          end
        end
      end
    end
  end
end
