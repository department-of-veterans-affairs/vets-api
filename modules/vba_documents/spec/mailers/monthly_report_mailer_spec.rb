# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/spec/support/vba_document_fixtures'

RSpec.describe VBADocuments::MonthlyReportMailer, type: [:mailer] do
  include VBADocuments::Fixtures

  # TODO: Rewrite specs (next PR)
end
