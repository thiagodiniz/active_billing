module ActiveBilling
  module Generators
    class ControllersGenerator < Rails::Generators::Base
      source_root ActiveBilling::Engine.root.join("app", "controllers", "active_billing").to_s

      desc "Copies ActiveBilling portal controllers into your application so you can override the defaults."

      def copy_controllers
        directory ".", "app/controllers/active_billing"
      end
    end
  end
end
