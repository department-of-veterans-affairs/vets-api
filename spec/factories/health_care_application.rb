# frozen_string_literal: true

FactoryBot.define do
  factory :health_care_application do
    form { 
      File.read(
        Rails.root.join('spec', 'fixtures', 'hca', 'veteran.json')
      )
     }

    factory(:hca_app_with_attachment) do
      after(:build) do |health_care_application|
        form = health_care_application.parsed_form
        form['attachments'] = [
          {
            'confirmationCode' => create(:hca_attachment).guid,
            'dd214' => true
          },
          {
            'confirmationCode' => create(:hca_attachment).guid,
            'dd214' => false
          }
        ]
        health_care_application.form = form.to_json
        health_care_application.send(:remove_instance_variable, :@parsed_form)
      end
    end
  end
end
