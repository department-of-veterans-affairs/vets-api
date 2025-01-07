# frozen_string_literal: true

namespace :remediation do
  desc 'Process 0781 forms for research (without uploading)'
  task process_0781: :environment do
    require Rails.root.join('lib', 'tasks', 'remediation',
                            'process_0781_remediation')

    Remediation::Process0781.run
  end
end
