module ActiveBilling
  module Generators
    # Ejects the jbuilder views for one API resource so they can be customized.
    # Example:
    #
    #   rails g active_billing:api_views invoices
    class ApiViewsGenerator < Rails::Generators::NamedBase
      source_root ActiveBilling::Engine.root.join("app", "views", "active_billing", "api", "v1").to_s

      desc "Copies one API resource's jbuilder views into your app so you can override the defaults."

      def copy_views
        directory file_name, "app/views/active_billing/api/v1/#{file_name}"
      end
    end
  end
end
