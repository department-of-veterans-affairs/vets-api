# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require 'olive_branch_patch'

describe 'form526 rake tasks', type: :request do
  let(:user) { build(:disabilities_compensation_user) }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:headers_with_camel) { headers.merge('HTTP_X_KEY_INFLECTION' => 'camel') }
  let(:in_progress_form526_original) do
    JSON.parse(File.read(
                 'spec/support/disability_compensation_form/526_in_progress_form_maixmal.json'
               ))
  end

  let!(:in_progress_form) do
    form_json = JSON.parse(File.read('spec/support/disability_compensation_form/526_in_progress_form_maixmal.json'))
    FactoryBot.create(:in_progress_form,
                      user_uuid: user.uuid,
                      form_id: '21-526EZ',
                      form_data: to_case(:dasherize, to_case(:camelize, to_case(:dasherize, form_json['formData']))),
                      metadata: to_case(:dasherize, to_case(:camelize, to_case(:dasherize, form_json['metadata']))))
  end

  before :all do
    Rake.application.rake_require '../rakelib/form526'
    Rake::Task.define_task(:environment)
  end

  describe 'rake form526:convert_sip_data' do
    let(:path_to_csv) { 'tmp/rake_task_output.csv' }

    let :run_rake_task do
      Rake::Task['form526:convert_sip_data'].reenable
      Rake.application.invoke_task "form526:convert_sip_data[#{path_to_csv}]"
    end

    it 'fixes the form data with the rake task' do
      in_progress_form
      expect(in_progress_form.form_data).to include('aaaaa camel_case nightmare_w_easdf123_asdf')
      expect { run_rake_task }.not_to raise_error
      fixed_form = InProgressForm.find(in_progress_form.id)
      expect(fixed_form.form_data).to include('AAAAA CamelCase nightmareWEasdf-123--asdf')
      expect(fixed_form.form_data).not_to include('aaaaa camel_case nightmare_w_easdf123_asdf')
    end

    it 'returns the data that was sent from the FE to the BE unharmed' do
      sign_in_as(user)
      put '/v0/in_progress_forms/21-526EZ', params: in_progress_form.to_json, headers: headers_with_camel
      run_rake_task
      get '/v0/in_progress_forms/21-526EZ', headers: headers
      response_json = JSON.parse(response.body)
      # TODO: form_data will become form_data soon
      expect(response_json['form_data']).to eq(in_progress_form526_original['formData'])
    end
  end
end

def to_case(method, val)
  if method == :dasherize
    val.deep_transform_keys!(&:underscore)
  else

    OliveBranch::Transformations.transform(
      val,
      OliveBranch::Transformations.method(method)
    )
  end
end
