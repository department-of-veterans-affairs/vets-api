shared_examples_for 'skip_sentry_404' do
  before do
    allow_any_instance_of(described_class).to receive(:authenticate) do
      raise Common::Exceptions::RecordNotFound, 'some_id'
    end

    controller_klass = described_class
    Rails.application.routes.draw do
      get '/authenticate' => "#{ controller_klass.to_s.underscore.gsub('_controller', '')}#authenticate"
    end
  end

  it 'should not log 404 to sentry' do
    allow_any_instance_of(ApplicationController).to receive(:log_exception_to_sentry) { raise }

    get(controller.present? ? :authenticate : '/authenticate')
    expect(response.code).to eq('404')
  end
end
