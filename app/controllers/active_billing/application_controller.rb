module ActiveBilling
  # Inherits from `ActiveBilling.configuration.parent_controller` so the host app's
  # authentication, CSRF configuration and helpers apply to the engine's pages.
  class ApplicationController < ActiveBilling.configuration.parent_controller.constantize
    layout "active_billing/application"
  end
end
