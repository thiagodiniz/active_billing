module ActiveBilling
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates an ActiveBilling initializer and prints the remaining setup steps."

      def copy_initializer
        template "active_billing.rb", "config/initializers/active_billing.rb"
      end

      def show_next_steps
        say ""
        say "ActiveBilling initializer created at config/initializers/active_billing.rb", :green
        say ""
        say "Next steps:"
        say "  1. Mount the engine in config/routes.rb:"
        say "       mount ActiveBilling::Engine => \"/billing\""
        say "  2. Install and run the migrations:"
        say "       bin/rails active_billing:install:migrations"
        say "       bin/rails db:migrate"
        say "  3. (Optional) Copy views or controllers to override the defaults:"
        say "       bin/rails generate active_billing:views"
        say "       bin/rails generate active_billing:controllers"
        say ""
      end
    end
  end
end
