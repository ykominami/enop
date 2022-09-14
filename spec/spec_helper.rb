$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'enop'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

class TestSetup
  def self.setup(token, url, env, remote = false)
    config = nil
    env ||= "production"

    banner = "Usage: bundle exec ruby exe/enop"

    hs = {
      "output_dir" => "output",
      "db_dir" => Arxutils_Sqlite3::Config::DB_DIR,
      "config_dir" => Arxutils_Sqlite3::Config::CONFIG_DIR,
      "env" => env,
      "dbconfig" => Arxutils_Sqlite3::Config::DBCONFIG_SQLITE3,
    }
    enop = Enop::Enop.new(
                          token,
                          hs,
                          url,
                          )
    enop.connect
    enop
  end
end
