# frozen_string_literal: true

class DirectDepositMailer < TransactionalEmailMailer
  SUBJECT = 'Confirmation - Your direct deposit information changed on VA.gov'
  GA_CAMPAIGN_NAME = 'direct-deposit-update' # TODO: confirm
  GA_DOCUMENT_PATH = '/placeholder' # TODO: replace
  GA_LABEL = 'placeholder' # TODO: replace

  TEMPLATE = 'direct_deposit'
end
