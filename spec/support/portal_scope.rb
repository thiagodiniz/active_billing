module PortalScope
  HEADER = "X-Store-Id".freeze
  RESOLVER = ->(controller) { Store.find_by(id: controller.request.headers[HEADER]) }

  def as_entity(entity)
    { HEADER => entity.id.to_s }
  end
end

RSpec.configure do |config|
  config.include PortalScope, type: :request

  config.around(:each, type: :request) do |example|
    original = ActiveBilling.configuration.dup
    ActiveBilling.configuration.portal_billable_entity = PortalScope::RESOLVER
    example.run
  ensure
    ActiveBilling.configuration = original
  end
end
