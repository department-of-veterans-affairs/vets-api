# frozen_string_literal: true

class DirectDepositMailer < TransactionalEmailMailer
  SUBJECT = 'Confirmation - Your direct deposit information changed on VA.gov'
  GA_CAMPAIGN_NAME = 'direct-deposit-update'
  GA_DOCUMENT_PATH = '/email/profile'
  GA_LABEL = 'direct-deposit-update'

  TEMPLATE = 'direct_deposit'

  DD_TYPES = {
    comp_pen: 'disability compensation or pension'
  }.freeze

  def build(email, google_analytics_client_id, dd_type)
    @dd_text = DD_TYPES[dd_type.to_sym]
    super(email, google_analytics_client_id)
  end
end
