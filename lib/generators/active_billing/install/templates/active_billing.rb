ActiveBilling.configure do |config|
  # Currency used when formatting monetary amounts.
  config.currency = :BRL

  # Default late-payment penalty and interest, in cents.
  config.default_penalty  = 200
  config.default_interest = 100

  # Default billing cycle interval.
  config.default_cycle_interval = :monthly

  # Method the host app exposes to resolve the entity that receives payments.
  config.billing_entity_method = :billing_entity

  # Default polymorphic type for portal pages when billable_entity_type is not
  # passed as a query param, e.g. "Store" or "Organization".
  config.billable_entity_class = nil

  # Controller the engine's portal controllers inherit from. Point it at your own
  # base controller so the portal runs behind your authentication and layout.
  config.parent_controller = "ActionController::Base"

  # Resolve the billable entity the portal is scoped to from the request (e.g. the
  # signed-in user's organization). When set, the billable_entity_* query params
  # are ignored so users cannot browse other entities' data.
  # config.portal_billable_entity = ->(controller) { controller.current_user&.organization }

  # Issuer details printed on invoice PDFs (required for PDF rendering).
  # config.company = {
  #   name: "Example, LLC",
  #   address: "123 Fake Street\nNew York City, NY 10012",
  #   email: "billing@example.com",
  #   phone: "+1 555 000 0000",
  #   logo: Rails.root.join("app/assets/images/logo.png")
  # }

  # Recipient lines printed on invoice PDFs. Defaults to the billable entity's
  # name, address, email and tax_id when it responds to them.
  # config.invoice_recipient = ->(invoice) { [invoice.billing.billable_entity.name] }

  # Footer message and page size for invoice PDFs.
  # config.invoice_pdf_footer = "Thanks for your business."
  # config.invoice_pdf_page_size = "A4"
end
