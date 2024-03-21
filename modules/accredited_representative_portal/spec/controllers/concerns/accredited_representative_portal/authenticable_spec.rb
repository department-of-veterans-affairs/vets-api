# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/authentication'

RSpec.describe AccreditedRepresentativePortal::Authenticable do
  controller(AccreditedRepresentativePortal::ApplicationController) do
    def index
      head :ok
    end
  end

  let(:representative_user) { create(:representative_user) }

  before do
    login_as(representative_user)
  end

  it 'loads the current rep user from the overridden load_user_object method' do
    expect(AccreditedRepresentativePortal::RepresentativeUserLoader).to receive(:new).and_call_original

    get :index
    expect(controller.instance_variable_get(:@current_user)).to be_a(AccreditedRepresentativePortal::RepresentativeUser)
  end
end
