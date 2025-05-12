# frozen_string_literal: true

class DirectDepositMailer < TransactionalEmailMailer
  SUBJECT = 'Confirmation - Your direct deposit information changed on VA.gov'
  GA_CAMPAIGN_NAME = 'direct-deposit-update'
  GA_DOCUMENT_PATH = '/email/profile'
  GA_LABEL = 'direct-deposit-update'
  TEMPLATE = 'direct_deposit'
end
