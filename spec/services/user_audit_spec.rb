# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAudit do
  describe '.logger' do
    subject(:logger) { described_class.logger }

    it 'returns an instance of UserAudit::Logger' do
      expect(logger).to be_a(UserAudit::Logger)
    end

    it 'appends the the appenders to SemanticLogger' do
      logger

      expect(SemanticLogger.appenders).to include(UserAudit::Appenders::AuditLogAppender)
      expect(SemanticLogger.appenders).to include(UserAudit::Appenders::UserActionAppender)
    end
  end
end
