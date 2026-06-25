module ActiveBilling
  module Generators
    class ViewsGenerator < Rails::Generators::Base
      source_root ActiveBilling::Engine.root.join("app", "views", "active_billing").to_s

      desc "Copies ActiveBilling portal views into your application so you can override the defaults."

      def copy_views
        directory ".", "app/views/active_billing"
      end
    end
  end
end
