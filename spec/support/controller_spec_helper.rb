# frozen_string_literal: true

shared_examples_for 'a controller that does not log 404 to Sentry' do
  before do
    allow_any_instance_of(described_class).to receive(:authenticate) do
      raise Common::Exceptions::RecordNotFound, 'some_id'
    end
  end

  it 'should not log 404 to sentry' do
    with_routing do |routes|
      @routes = routes
      controller_klass = described_class
      routes.draw do
        get '/fake_route' => "#{controller_klass.to_s.underscore.gsub('_controller', '')}#authenticate"
      end
      allow_any_instance_of(ApplicationController).to receive(:log_exception_to_sentry) { raise }
      get(controller.present? ? :authenticate : '/fake_route')
      expect(response.code).to eq('404')
    end
  end
end

shared_examples_for 'a controller that deletes an InProgressForm' do |param_name, form_name, form_id|
  let(:form) { build(form_name.to_sym) }
  let(:param_name) { param_name.to_sym }
  let(:form_id) { form_id }

  describe '#create' do
    def send_create
      post(:create, param_name => { form: form.form })
    end

    context 'with a valid form' do
      context 'with a user' do
        let(:user) { create(:user) }
        it 'deletes the "in progress form"' do
          create(:in_progress_form, user_uuid: user.uuid, form_id: form_id)
          controller.instance_variable_set(:@current_user, user)
          expect(controller).to receive(:clear_saved_form).with(form_id).and_call_original
          expect(controller).to receive(:authenticate_token)
          expect { send_create }.to change { InProgressForm.count }.by(-1)
        end
      end
    end
  end
end
