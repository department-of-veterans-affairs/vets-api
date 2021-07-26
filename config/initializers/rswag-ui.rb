# frozen_string_literal: true

Rswag::Ui.configure do |c|
  c.swagger_endpoint '/services/claims/docs/v1/api', 'Claims API V1 Docs'
  c.swagger_endpoint '/services/claims/docs/v0/api', 'Claims API V0 Docs'
end
