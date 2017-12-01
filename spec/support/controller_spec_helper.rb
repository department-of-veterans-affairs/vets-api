# frozen_string_literal: true
shared_examples_for 'a controller that does not log 404 to Sentry' do
  before do
    allow_any_instance_of(described_class).to receive(:authenticate) do
      raise Common::Exceptions::RecordNotFound, 'some_id'
    end

    controller_klass = described_class
    Rails.application.routes.draw do
      get '/fake_route' => "#{controller_klass.to_s.underscore.gsub('_controller', '')}#authenticate"
    end
  end

  it 'should not log 404 to sentry' do
    allow_any_instance_of(ApplicationController).to receive(:log_exception_to_sentry) { raise }

    get(controller.present? ? :authenticate : '/fake_route')
    expect(response.code).to eq('404')
  end

  after do
    Rails.application.reload_routes!
  end
end
