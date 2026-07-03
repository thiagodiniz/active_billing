module ActiveBilling
  module Generators
    # Ejects a single API controller into the host app so it can be customized.
    # Rails resolves the app's app/controllers ahead of the engine's, so the copy
    # transparently overrides the built-in one. Example:
    #
    #   rails g active_billing:api_controller charges
    class ApiControllerGenerator < Rails::Generators::NamedBase
      source_root ActiveBilling::Engine.root.join("app", "controllers", "active_billing", "api", "v1").to_s

      desc "Copies one ActiveBilling API controller into your app so you can override the default."

      def copy_controller
        copy_file "#{file_name}_controller.rb",
                  "app/controllers/active_billing/api/v1/#{file_name}_controller.rb"
      end
    end
  end
end
