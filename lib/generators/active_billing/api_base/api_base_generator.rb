module ActiveBilling
  module Generators
    # Ejects the API BaseController for cross-cutting overrides (e.g. custom auth,
    # a different error envelope). Example:
    #
    #   rails g active_billing:api_base
    class ApiBaseGenerator < Rails::Generators::Base
      source_root ActiveBilling::Engine.root.join("app", "controllers", "active_billing", "api", "v1").to_s

      desc "Copies the ActiveBilling API base controller into your app so you can override it."

      def copy_base_controller
        copy_file "base_controller.rb", "app/controllers/active_billing/api/v1/base_controller.rb"
      end
    end
  end
end
