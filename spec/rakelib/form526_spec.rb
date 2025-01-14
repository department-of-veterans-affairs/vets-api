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
    create(:in_progress_form,
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
      # corrupted before, with snake case keys in db
      form_data_json = JSON.parse(in_progress_form.form_data)
      expect(form_data_json['va_treatment_facilities'].first['treated_disability_names'].keys).to(
        include('aaaaa camelcase nightmareweasdf123_asdf')
      )
      expect(form_data_json['view:is_pow']['pow_disabilities'].keys).to(
        include('aaaaa camelcase nightmareweasdf123_asdf')
      )

      expect { run_rake_task }.not_to raise_error

      # fixed, after with camel case in db
      fixed_form = InProgressForm.find(in_progress_form.id).form_data
      fixed_form_json = JSON.parse(fixed_form)

      expect(fixed_form_json['vaTreatmentFacilities'].first['treatedDisabilityNames'].keys).to(
        include('aaaaa camelcase nightmareweasdf-123--asdf')
      )
      expect(fixed_form_json['view:isPow']['powDisabilities'].keys).to(
        include('aaaaa camelcase nightmareweasdf-123--asdf')
      )
      expect(fixed_form).not_to include('aaaaa camel_case nightmare_w_easdf123_asdf')
    end

    it 'returns the data that was sent from the FE to the BE unharmed' do
      sign_in_as(user)
      put '/v0/in_progress_forms/21-526EZ', params: in_progress_form.to_json, headers: headers_with_camel
      run_rake_task
      get('/v0/in_progress_forms/21-526EZ', headers:)
      response_json = JSON.parse(response.body)
      expect(response_json['formData']).to eq(in_progress_form526_original['formData'])
    end
  end

  describe 'rake form526:submissions' do
    let!(:form526_submission) { create(:form526_submission, :with_mixed_status) }

    def run_rake_task(args_string)
      Rake::Task['form526:submissions'].reenable
      Rake.application.invoke_task "form526:submissions[#{args_string}]"
    end

    context 'runs without errors' do
      [
        ['', 'no args'],
        ['2020-12-25', 'just a start date'],
        [',2020-12-25', 'just an end date'],
        ['2020-12-24,2020-12-25', 'two dates'],
        ['bdd', 'bdd stats mode']
      ].each do |(args_string, desc)|
        it desc do
          expect { silently { run_rake_task(args_string) } }.not_to raise_error
        end
      end
    end
  end

  describe 'rake form526:errors' do
    let!(:form526_submission) { create(:form526_submission, :with_one_failed_job) }
    let :run_rake_task do
      Rake::Task['form526:errors'].reenable
      Rake.application.invoke_task 'form526:errors'
    end

    it 'runs without errors' do
      expect { silently { run_rake_task } }.not_to raise_error
    end
  end

  describe 'rake form526:submission' do
    let!(:form526_submission) { create(:form526_submission, :with_mixed_status) }
    let :run_rake_task do
      Rake::Task['form526:submission'].reenable
      Rake.application.invoke_task "form526:submission[#{form526_submission.id}]"
    end

    it 'runs without errors' do
      expect { silently { run_rake_task } }.not_to raise_error
    end
  end

  describe 'rake form526:mpi' do
    let(:submission) { create(:form526_submission) }
    let(:profile) { build(:mpi_profile) }
    let(:profile_response) { create(:find_profile_response, profile:) }
    let(:run_rake_task) do
      Rake::Task['form526:mpi'].reenable
      Rake.application.invoke_task "form526:mpi[#{submission.id}]"
    end

    it 'runs without errors' do
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_edipi).and_return(profile_response)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
      expect { silently { run_rake_task } }.not_to raise_error
    end
  end

  describe 'rake form526:pif_errors' do
    let!(:submission) { create(:form526_submission, :with_pif_in_use_error) }
    let :run_rake_task do
      Rake::Task['form526:pif_errors'].reenable
      Rake.application.invoke_task 'form526:pif_errors'
    end

    it 'runs without errors' do
      expect { silently { run_rake_task } }.not_to raise_error
    end
  end
end

def silently
  # Store the original stderr and stdout in order to restore them later
  @original_stderr = $stderr
  @original_stdout = $stdout

  # Redirect stderr and stdout
  $stderr = $stdout = StringIO.new

  yield

  $stderr = @original_stderr
  $stdout = @original_stdout
  @original_stderr = nil
  @original_stdout = nil
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
