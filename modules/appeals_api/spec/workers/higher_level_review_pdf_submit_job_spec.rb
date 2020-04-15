# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::HigherLevelReviewPdfSubmitJob, type: :job do
  let(:client_stub) { instance_double('CentralMail::Service') }
end

